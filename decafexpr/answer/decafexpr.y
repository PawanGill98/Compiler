%{
#include <iostream>
#include <ostream>
#include <string>
#include <cstdlib>
#include "default-defs.h"

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

// dummy main function
// WARNING: this is not how you should implement code generation
// for the main function!
// You should write the codegen for the main method as 
// part of the codegen for method declarations (MethodDecl)
static llvm::Function *TheFunction = 0;

// we have to create a main function 
llvm::Function *gen_main_def() {
  // create the top-level definition for main
  llvm::FunctionType *FT = llvm::FunctionType::get(llvm::IntegerType::get(TheContext, 32), false);
  llvm::Function *TheFunction = llvm::Function::Create(FT, llvm::Function::ExternalLinkage, "2main", TheModule);
  if (TheFunction == 0) {
    throw runtime_error("empty function block"); 
  }
  // Create a new basic block which contains a sequence of LLVM instructions
  llvm::BasicBlock *BB = llvm::BasicBlock::Create(TheContext, "entry", TheFunction);
  // All subsequent calls to IRBuilder will place instructions in this location
  Builder.SetInsertPoint(BB);
  return TheFunction;
}

llvm::Function *gen_print_int_def() {
  // create a extern definition for print_int
  std::vector<llvm::Type*> args;
  args.push_back(llvm::IntegerType::get(TheContext, 32)); // print_int takes one integer argument
  llvm::FunctionType *print_int_type = llvm::FunctionType::get(llvm::IntegerType::get(TheContext, 32), args, false);
  return llvm::Function::Create(print_int_type, llvm::Function::ExternalLinkage, "print_int", TheModule);
}

#include "decafexpr.cc"

%}

%union{
    class decafAST *ast;
    std::string *sval;
    int ival;
    arr s;
    std::vector<std::string> *vecptr;

 }

%token T_VAR
%token <sval> T_SEMICOLON
%token T_COMMA
%token <sval> T_INTTYPE
%token T_LSB
%token <sval> T_INTCONSTANT
%token T_RSB
%token T_ASSIGN
%token <sval> T_BOOLTYPE
%token <sval> T_CHARCONSTANT
%token <sval> T_TRUE
%token <sval> T_FALSE

%token T_LPAREN
%token T_RPAREN
%token <sval> T_STRINGTYPE
%token T_EXTERN
%token T_FUNC

%token T_PACKAGE
%token T_LCB
%token T_RCB
%token <sval> T_ID
%token <sval> T_VOID

%token <sval> T_PLUS T_MINUS T_DIV T_MULT T_MOD T_EQ T_NEQ T_LEFTSHIFT T_RIGHTSHIFT T_LT T_GT T_GEQ T_LEQ T_AND T_OR T_NOT

%left T_OR
%left T_AND
%left T_EQ T_NEQ
%left T_GEQ T_LEQ T_LT T_RT
%left T_PLUS T_MINUS 
%left T_LEFTSHIFT T_RIGHTSHIFT
%left T_MULT T_DIV T_MOD

%token T_IF
%token T_WHILE
%token T_FOR
%token T_ELSE
%token T_RETURN
%token <sval> T_CONTINUE
%token <sval> T_BREAK
%token <sval> T_STRINGCONSTANT





%type <sval> arithmetic_operator boolean_operator



%type <sval> binary_operator unary_operator
%type <ast> constant
%type <vecptr> id_list
%type <ast> statements statement assign assign_list return_stmt if_stmt while_stmt for_stmt block expr method_arg method_arg_list method_call


%type <ast> extern_list decafpackage extern_type_list extern_defn
%type <ast> method_decls method_block var_decl var_decls method_parameter_list method_decl field_decl field_decls value
%type <sval> decaf_type extern_type method_type
%type <s> array_type

%%

start: program

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
        ExternFunctionAST *ex;
        ex = new ExternFunctionAST(*$3, *$7, (decafStmtList *)$5);
        $$ = ex;
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
        FieldDeclAST* node;
        for(int i = 0; i < $2->size(); i++) {
            node = new FieldDeclAST((*$2)[i], *$3, "Scalar", false);
            slist->push_back(node);
        }
        $$ = slist;
    }
    | T_VAR id_list array_type T_SEMICOLON
    {
        decafStmtList* slist = new decafStmtList();
        FieldDeclAST* node;
        for(int i = 0; i < $2->size(); i++) {
            node = new FieldDeclAST((*$2)[i], *$3.type, *$3.size, false);
            slist->push_back(node);
        }
        $$ = slist;
    }
    | T_VAR id_list decaf_type T_ASSIGN constant T_SEMICOLON
    {
        $$ = new FieldDeclAST((*$2)[0], *$3, getString((decafAST *)$5), true);
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
            { symtbl.push_front(symbol_table()); }
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
    | T_BREAK T_SEMICOLON
    {
        decafStr *str_id = new decafStr(*$1);
        $$ = str_id;
    }
    | T_CONTINUE T_SEMICOLON
    {
        decafStr *str_id = new decafStr(*$1);
        $$ = str_id;
    }
    ;

block: begin_block var_decls statements end_block
    {
        BlockAST *block;
        block = new BlockAST((decafStmtList *)$2, (decafStmtList *)$3);
        $$ = block;
    }
    ;

expr: value
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

value: T_ID T_LSB expr T_RSB
     {        
       ValueAST* v;
       v = new ValueAST(*$1, (decafStmtList*) $3);
       $$ = v;
     }
     | T_ID 
     { 
       ValueAST* v;
       v = new ValueAST(*$1);
       $$ = v;
     }   
     ;

constant: T_INTCONSTANT
    {
        ConstantAST *c;
        c = new ConstantAST(*$1, true);
        $$ = c; 
    }
    | T_CHARCONSTANT
    {
        ConstantAST *c;
        c = new ConstantAST(ctoi(*$1), true);
        $$ = c; 
    }
    | T_TRUE
    {
        ConstantAST *c;
        c = new ConstantAST(*$1, false);
        $$ = c; 
    }
    | T_FALSE
    {
        ConstantAST *c;
        c = new ConstantAST(*$1, false);
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

binary_operator: arithmetic_operator
    { $$ = $1; }
    | boolean_operator
    { $$ = $1; }
    ;

arithmetic_operator: T_PLUS
    { $$ = $1; }
    | T_MINUS
    { $$ = $1; }
    | T_MOD
    { $$ = $1; }
    | T_DIV
    { $$ = $1; }
    | T_MULT
    { $$ = $1; }
    | T_LEFTSHIFT
    { $$ = $1; }
    | T_RIGHTSHIFT
    { $$ = $1; }
    ;

boolean_operator: T_AND
    { $$ = $1; }
    | T_OR
    { $$ = $1; }
    | T_LEQ
    { $$ = $1; }
    | T_GEQ
    { $$ = $1; }
    | T_GT
    { $$ = $1; }
    | T_LT
    { $$ = $1; }
    | T_EQ
    { $$ = $1; }
    | T_NEQ
    { $$ = $1; }
    ;

unary_operator: T_NOT
    { $$ = $1; }
    | T_MINUS
    {
        $$ = new string("UnaryMinus");
    }
    ;

assign: value T_ASSIGN expr
    {
        //decafStr *id = new decafStr( string("AssignVar") + "(" + *$1 + "," + getString((decafAST *)$3) + ")" );
        //$$ = id;
        AssignAST *a;
        a = new AssignAST((ValueAST*)$1,$3);
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
        if_s = new IfAST((decafAST *)$3, (decafStmtList *)$5, new decafStmtList());
        $$ = if_s;
    }
    | T_IF T_LPAREN expr T_RPAREN block T_ELSE block
    {
        IfAST *if_s;
        if_s = new IfAST((decafAST *)$3, (decafStmtList *)$5, new decafStmtList());
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

ignore: ignore T_ID
    | ignore T_LCB
    | ignore T_RCB
	| T_ID
	| T_LCB
	| T_RCB
	;

%%

int main() {
  // initialize LLVM
  llvm::LLVMContext &Context = TheContext;
  // Make the module, which holds all the code.
  TheModule = new llvm::Module("Test", Context);
  // set up symbol table
  symtbl.push_front(symbol_table());
  // set up dummy main function
  //TheFunction = gen_main_def();
  // parse the input and create the abstract syntax tree
  int retval = yyparse();
  // remove symbol table
  symtbl.pop_front();
  // Finish off the main function. (see the WARNING above)
  // return 0 from main, which is EXIT_SUCCESS
  //Builder.CreateRet(llvm::ConstantInt::get(TheContext, llvm::APInt(32, 0)));
  // Validate the generated code, checking for consistency.
  //verifyFunction(*TheFunction);
  // Print out all of the generated code to stderr
  TheModule->print(llvm::errs(), nullptr);
  return(retval >= 1 ? EXIT_FAILURE : EXIT_SUCCESS);
}

