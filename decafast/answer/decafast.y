%{
#include <iostream>
#include <ostream>
#include <string>
#include <cstdlib>
#include "default-defs.h"

int yylex(void);
int yyerror(char *); 

// print AST?
bool printAST = true;

#include "decafast.cc"

using namespace std;

%}

%define parse.error verbose

%union{
    class decafAST *ast;
    std::string *sval;
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

%token T_PACKAGE
%token T_LCB
%token T_RCB
%token <sval> T_ID

%type <ast> extern_list decafpackage

%type <ast> field_decls field_decl

%type <sval> type
%type <sval> constant
%type <s> array_type
%type <vecptr> id_list

%%

start: program

program: extern_list decafpackage
    { 
        ProgramAST *prog = new ProgramAST((decafStmtList *)$1, (PackageAST *)$2); 
		if (printAST) {
			cout << getString(prog) << endl;
		}
        delete prog;
    }

extern_list: /* extern_list can be empty */
    { decafStmtList *slist = new decafStmtList(); $$ = slist; }
    ;

decafpackage: T_PACKAGE T_ID T_LCB field_decls T_RCB
    { $$ = new PackageAST(*$2, (decafStmtList *)$4, new decafStmtList()); delete $2; }
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

field_decl: T_VAR id_list type T_SEMICOLON
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
    | T_VAR id_list type T_ASSIGN constant T_SEMICOLON
    {
        $$ = new FieldDeclAST((*$2)[0], *$3, *$5, true);
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

type: T_INTTYPE
    { $$ = $1; }
    | T_BOOLTYPE
    { $$ = $1; }
    ;

array_type: T_LSB T_INTCONSTANT T_RSB type
    {
        arr s;
        s.size = $2;
        s.type = $4;
        $$ = s;
    }
    ;

constant: T_INTCONSTANT
    { $$ = $1; }
    | T_CHARCONSTANT
    { $$ = $1; }
    | T_TRUE
    { $$ = $1; }
    | T_FALSE
    { $$ = $1; }

%%

int main() {
  // parse the input and create the abstract syntax tree
  int retval = yyparse();
  return(retval >= 1 ? EXIT_FAILURE : EXIT_SUCCESS);
}

