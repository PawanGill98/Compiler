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
 }

%token T_VAR
%token T_INT
%token T_SEMICOLON

%token T_PACKAGE
%token T_LCB
%token T_RCB
%token <sval> T_ID

%type <ast> extern_list decafpackage

%type <ast> field_decls field_decl

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

field_decl: T_VAR T_ID T_INT T_SEMICOLON
    { $$ = new FieldDeclAST(*$2); delete $2; }
    ;

%%

int main() {
  // parse the input and create the abstract syntax tree
  int retval = yyparse();
  return(retval >= 1 ? EXIT_FAILURE : EXIT_SUCCESS);
}

