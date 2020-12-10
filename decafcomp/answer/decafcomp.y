%{
#include <iostream>
#include <ostream>
#include <string>
#include <cstdlib>
#include "decafcomp-defs.h"

int yylex(void);
int yyerror(char *); 

// print AST?
bool printAST = false;

using namespace std;

// this global variable contains all the generated code
static llvm::Module *TheModule;

// this is the method used to construct the LLVM intermediate code (IR)
static llvm::LLVMContext TheContext;
static llvm::IRBuilder<> Builder(TheContext);
// the calls to TheContext in the init above and in the
// following code ensures that we are incrementally generating
// instructions in the right order

#include "decafcomp.cc"

%}

%union{
    class decafAST *ast;
    std::string *sval;
    int ival;
    arr s;
    std::vector<std::string> *vecptr;

 }

%token T_EXTERN
%token T_FUNC
%token T_PACKAGE

%token T_LCB
%token T_RCB
%token T_LSB
%token T_RSB
%token T_LPAREN
%token T_RPAREN
%token T_COMMA
%token <sval> T_SEMICOLON

%token T_IF
%token T_ELSE
%token T_FOR
%token T_WHILE
%token T_BREAK
%token T_CONTINUE
%token T_RETURN

%token T_VAR
%token T_ASSIGN

%token <sval> T_VOID
%token <sval> T_INTTYPE
%token <sval> T_BOOLTYPE
%token <sval> T_STRINGTYPE
%token <sval> T_TRUE
%token <sval> T_FALSE

%token <sval> T_PLUS T_MINUS T_DIV T_MULT T_MOD T_EQ T_NEQ T_LEFTSHIFT T_RIGHTSHIFT T_LT T_GT T_LEQ T_GEQ T_AND T_OR T_NOT

%left T_OR
%left T_AND
%left T_EQ T_NEQ
%left T_LT T_GT T_LEQ T_GEQ
%left T_PLUS T_MINUS
%left T_LEFTSHIFT T_RIGHTSHIFT
%left T_MULT T_DIV T_MOD

%token <sval> T_INTCONSTANT
%token <sval> T_CHARCONSTANT
%token <sval> T_STRINGCONSTANT
%token <sval> T_ID

%type <ast> extern_list extern_defn extern_type_list
%type <ast> decafpackage
%type <ast> field_decls field_decl
%type <ast> method_decls method_decl method_parameter_list method_block
%type <ast> var_decls var_decl
%type <ast> statements statement

%type <ast> block assign_list assign method_call method_arg_list method_arg
%type <ast> if_stmt for_stmt while_stmt break_stmt continue_stmt return_stmt
%type <ast> expr constant value_var value_arr

%type <sval> decaf_type extern_type method_type
%type <s> array_type
%type <vecptr> id_list

%%

start: program;

program: extern_list decafpackage
    { 
        ProgramAST *prog = new ProgramAST((decafStmtList *)$1, (PackageAST *)$2); 
		if (printAST) {
			cout << getString(prog) << endl;
		}
        try {
            prog->Codegen();
        } 
        catch (std::runtime_error &e) {
            cout << "semantic error: " << e.what() << endl;
            //cout << prog->str() << endl; 
            exit(EXIT_FAILURE);
        }
        delete prog;
    }
    ;

extern_list: /* extern_list can be empty */
    { decafStmtList *slist = new decafStmtList(); $$ = slist; }
	| extern_defn extern_list
    {
        decafStmtList* slist;
        if($2 == NULL) {
            slist = new decafStmtList();
        }
        else {
            slist = (decafStmtList *)$2;
        }
        slist->push_front($1);
        $$ = slist;
    }
    ;

extern_defn: T_EXTERN T_FUNC T_ID T_LPAREN extern_type_list T_RPAREN method_type T_SEMICOLON
    {
        ExternFunctionAST *externDef;
        externDef = new ExternFunctionAST(*$3, *$7, (decafStmtList *)$5);
        $$ = externDef;
    }
    ;

extern_type_list:
    {
        $$ = NULL;
    }
    | extern_type T_COMMA extern_type_list
    {
        decafStmtList* elist;
        ExternVarDefAST *ex = new ExternVarDefAST(*$1);
        elist = (decafStmtList *)$3;
        elist->push_front(ex);
        $$ = elist;
    }
    | extern_type
    {
        decafStmtList* elist;
        elist = new decafStmtList();
        ExternVarDefAST *ex = new ExternVarDefAST(*$1);
        elist->push_front(ex);
        $$ = elist;
    }
    ;

decafpackage: T_PACKAGE T_ID begin_block end_block
    { $$ = new PackageAST(*$2, new decafStmtList(), new decafStmtList()); delete $2; }
    | T_PACKAGE T_ID begin_block field_decls method_decls end_block
    { $$ = new PackageAST(*$2, (decafStmtList*)$4, (decafStmtList*)$5); delete $2; }
    ;

field_decls:
    { $$ = NULL; }
    | field_decl field_decls
    {
        decafStmtList* slist;
        if($2 == NULL) {
            slist = new decafStmtList();
        }
        else {
            slist = (decafStmtList *)$2;
        }
        slist->push_front($1);
        $$ = slist;
    }
    ;

field_decl: T_VAR id_list decaf_type T_SEMICOLON
    {
        decafStmtList* slist = new decafStmtList();
        FieldDeclScalarAST* node;
        for(int i = 0; i < $2->size(); i++) {
            node = new FieldDeclScalarAST((*$2)[i], *$3);
            slist->push_back(node);
        }
        $$ = slist;
    }
    | T_VAR id_list array_type T_SEMICOLON
    {
        decafStmtList* slist = new decafStmtList();
        FieldDeclArrayAST* node;
        for(int i = 0; i < $2->size(); i++) {
            node = new FieldDeclArrayAST((*$2)[i], *$3.type, *$3.size);
            slist->push_back(node);
        }
        $$ = slist;
    }
    | T_VAR id_list decaf_type T_ASSIGN constant T_SEMICOLON
    {
        $$ = new FieldDeclAssignAST((*$2)[0], *$3, (decafAST *)$5);
    }
    ;

array_type: T_LSB T_INTCONSTANT T_RSB decaf_type
    {
        arr s;
        s.size = $2;
        s.type = $4;
        $$ = s;
    }
    ;

id_list: T_ID T_COMMA id_list
    {  
        vector<string>* ilist;
        ilist = $3;
        ilist->insert(ilist->begin(), *$1);
        delete $1;
        $$ = ilist;
    }
    | T_ID
    {  
        vector<string>* ilist;
        ilist = new vector<string>;
        ilist->insert(ilist->begin(), *$1);
        delete $1;
        $$ = ilist;
    }
    ;


method_decls: 
    { $$ = NULL; }
    | method_decl method_decls
    {
        decafStmtList* slist;
        if($2 == NULL) {
            slist = new decafStmtList();
        }
        else {
            slist = (decafStmtList *)$2;
        }
        slist->push_front($1);
        $$ = slist;
    }
    ;

method_decl: T_FUNC T_ID T_LPAREN method_parameter_list T_RPAREN method_type method_block
    {
        MethodDeclAST *method;
        method = new MethodDeclAST(*$2, *$6, (decafStmtList *)$4, (MethodBlockAST *)$7);
        $$ = method;
    }
    ;

method_parameter_list: 
    { $$ = NULL; }
    | T_ID decaf_type T_COMMA method_parameter_list
    {
        decafStmtList* mplist;
        MethodVarDefAST *mv = new MethodVarDefAST(*$1, *$2);
        mplist = (decafStmtList *)$4;
        mplist->push_front(mv);
        $$ = mplist;
    }
    | T_ID decaf_type
    {
        decafStmtList* mplist;
        mplist = new decafStmtList();
        MethodVarDefAST *mv = new MethodVarDefAST(*$1, *$2);
        mplist->push_front(mv);
        $$ = mplist;
    }
    ;

method_block: begin_block var_decls statements end_block
    {
        MethodBlockAST *block;
        block = new MethodBlockAST((decafStmtList *)$2, (decafStmtList *)$3);
        $$ = block;
    }
    ;

begin_block: T_LCB
            { 
                symtbl.push_front(symbol_table()); 
            }
            ;
  
end_block: T_RCB
            {
              symbol_table sym_table = symtbl.front();
              symtbl.pop_front();          
            }
            ;

var_decls:
    { $$ = NULL; }
    | var_decl var_decls
    {
        decafStmtList* vdlist;
        if($2 == NULL) {
            vdlist = new decafStmtList();
        }
        else {
            vdlist = (decafStmtList *)$2;
        }
        vdlist->push_front($1);
        $$ = vdlist;
    }
    ;

var_decl: T_VAR id_list decaf_type T_SEMICOLON
    {
        decafStmtList* vdlist = new decafStmtList();
        MethodVarDefAST* vd;
        for(int i = 0; i < $2->size(); i++) {
            vd = new MethodVarDefAST((*$2)[i], *$3);
            vdlist->push_back(vd);
        }
        $$ = vdlist;
    }
    ;

statements: statement statements
    {
        decafStmtList* slist;
        if($2 == NULL) {
            slist = new decafStmtList();
        }
        else {
            slist = (decafStmtList *)$2;
        }
        slist->push_front($1);
        $$ = slist;
    }
    |
    { $$ = NULL; }
    ;

statement: method_block
    { $$ = $1; }
    | block
    { $$ = $1; }
    | if_stmt
    { $$ = $1; }
    | while_stmt
    { $$ = $1; }
    | assign T_SEMICOLON
    { $$ = $1; }
    | method_call T_SEMICOLON
    { $$ = $1; }
    | return_stmt
    { $$ = $1; }
    | for_stmt
    { $$ = $1; }
    | break_stmt
    { $$ = $1; }
    | continue_stmt
    { $$ = $1; }
    ;

break_stmt: T_BREAK T_SEMICOLON
    {
        BreakAST *b;
        b = new BreakAST();
        $$ = b;
    }
    ;

continue_stmt: T_CONTINUE T_SEMICOLON
    {
        ContinueAST *c;
        c = new ContinueAST();
        $$ = c;
    }
    ;

block: begin_block var_decls statements end_block
    {
        BlockAST *block;
        block = new BlockAST((decafStmtList *)$2, (decafStmtList *)$3);
        $$ = block;
    }
    ;

expr: value_var
    { $$ = $1; }
    | value_arr
    { $$ = $1; }
    | method_call
    { $$ = $1; }
    | constant
    { $$ = $1; }
    | expr T_PLUS expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_MINUS expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_MULT expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_DIV expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_LEFTSHIFT expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_RIGHTSHIFT expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_MOD expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_EQ expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_NEQ expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_LT expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_LEQ expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_GT expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_GEQ expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_AND expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | expr T_OR expr
    {
        BinaryExpr *b;
        b = new BinaryExpr(*$2, (decafAST *)$1, (decafAST *)$3);
        $$ = b;
    }
    | T_NOT expr %prec T_MOD
    {
        UnaryExpr *u;
        u = new UnaryExpr(*$1, (decafAST *)$2);
        $$ = u;
    }
    | T_MINUS expr %prec T_MOD
    {
        UnaryExpr *u;
        u = new UnaryExpr("UnaryMinus", (decafAST *)$2);
        $$ = u;
    }
    | T_LPAREN expr T_RPAREN
    {  $$ = $2; }
    ;

value_var: T_ID 
     { 
        ValueVariableExprAST* v;
        v = new ValueVariableExprAST(*$1);
        $$ = v;
     }   
     ;

value_arr: T_ID T_LSB expr T_RSB
     {        
        ValueArrayLocExprAST* v;
        v = new ValueArrayLocExprAST(*$1, (decafAST*) $3);
        $$ = v;
     }
     ;

constant: T_INTCONSTANT
    {
        ConstantNumberExprAST *c;
        c = new ConstantNumberExprAST(*$1);
        $$ = c; 
    }
    | T_CHARCONSTANT
    {
        ConstantNumberExprAST *c;
        c = new ConstantNumberExprAST(ctoi(*$1));
        $$ = c; 
    }
    | T_TRUE
    {
        ConstantBoolExprAST *c;
        c = new ConstantBoolExprAST(*$1);
        $$ = c; 
    }
    | T_FALSE
    {
        ConstantBoolExprAST *c;
        c = new ConstantBoolExprAST(*$1);
        $$ = c; 
    }
    ;

method_call: T_ID T_LPAREN method_arg_list T_RPAREN
    {
        MethodCallAST *method;
        method = new MethodCallAST(*$1, (decafStmtList *)$3);
        $$ = method;
    }
    ;

method_arg: expr
    { $$ = $1; }
    | T_STRINGCONSTANT
    {
        StringConstantAST *s;
        s = new StringConstantAST(*$1);
        $$ = s;
    }
    ;

method_arg_list: method_arg T_COMMA method_arg_list
    {
        decafStmtList* mlist;
        decafAST *m = (decafAST *)$1;
        mlist = (decafStmtList *)$3;
        mlist->push_front(m);
        $$ = mlist;
    }
    | method_arg
    {
        decafStmtList* mlist;
        mlist = new decafStmtList();
        decafAST *m = (decafAST *)$1;
        mlist->push_front(m);
        $$ = mlist;
    }
    | 
    { $$ = NULL; }
    ;


assign: value_var T_ASSIGN expr
    {
        //decafStr *id = new decafStr( string("AssignVar") + "(" + *$1 + "," + getString((decafAST *)$3) + ")" );
        //$$ = id;
        AssignVarAST *a;
        a = new AssignVarAST((ValueVariableExprAST*)$1, $3);
        $$ = a;
    }
    | value_arr T_ASSIGN expr
    {
        AssignArrayAST *a;
        a = new AssignArrayAST((ValueArrayLocExprAST*)$1, $3);
        $$ = a;
    }
    ;

assign_list: assign T_COMMA assign_list
    {
        decafStmtList* alist;
        decafAST *a = (decafAST *)$1;
        alist = (decafStmtList *)$3;
        alist->push_front(a);
        $$ = alist;
    }
    | assign
    {
        decafStmtList* alist;
        alist = new decafStmtList();
        decafAST *a = (decafAST *)$1;
        alist->push_front(a);
        $$ = alist;
    }
    ;

for_stmt: T_FOR T_LPAREN assign_list T_SEMICOLON expr T_SEMICOLON assign_list T_RPAREN block
    {
        ForAST *for_s;
        for_s = new ForAST((decafStmtList *)$3, (decafAST *)$5, (decafStmtList *)$7, (decafAST *)$9);
        $$ = for_s;
    }
    ;

if_stmt: T_IF T_LPAREN expr T_RPAREN block
    {
        IfAST *if_s;
        if_s = new IfAST((decafAST *)$3, (BlockAST *)$5, NULL);
        $$ = if_s;
    }
    | T_IF T_LPAREN expr T_RPAREN block T_ELSE block
    {
        IfAST *if_s;
        if_s = new IfAST((decafAST *)$3, (BlockAST *)$5, (BlockAST *)$7);
        $$ = if_s;
    }
    ;

while_stmt: T_WHILE T_LPAREN expr T_RPAREN block
    {
        WhileAST *while_s;
        while_s = new WhileAST((decafAST *)$3, (decafStmtList *)$5);
        $$ = while_s;
    }
    ;



return_stmt: T_RETURN T_SEMICOLON
    {
        ReturnAST *return_s;
        return_s = new ReturnAST(NULL);
        $$ = return_s;
    }
    | T_RETURN T_LPAREN T_RPAREN T_SEMICOLON
    {
        ReturnAST *return_s;
        return_s = new ReturnAST(NULL);
        $$ = return_s;
    }
    | T_RETURN T_LPAREN expr T_RPAREN T_SEMICOLON
    {
        ReturnAST *return_s;
        return_s = new ReturnAST((decafStmtList *)$3);
        $$ = return_s;
    }
    ;



extern_type: T_STRINGTYPE
    {
        $$ = $1;
    }
    | decaf_type
    {
        $$ = $1;
    }
    ;

decaf_type: T_INTTYPE
    {
        $$ = $1;
    }
    | T_BOOLTYPE
    {
        $$ = $1;
    }
    ;

method_type: T_VOID
    {
        $$ = $1;
    }
    | decaf_type
    {
        $$ = $1;
    }
    ;

%%

int main() {
  // initialize LLVM
  llvm::LLVMContext &Context = TheContext;
  // Make the module, which holds all the code.
  TheModule = new llvm::Module("Test", Context);
  // set up symbol table
  symtbl.push_front(symbol_table());
  int retval = yyparse();
  // remove symbol table
  symtbl.pop_front();
  TheModule->print(llvm::errs(), nullptr);
  return(retval >= 1 ? EXIT_FAILURE : EXIT_SUCCESS);
}

