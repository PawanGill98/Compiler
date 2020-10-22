%{
#include "default-defs.h"
#include "decafast.tab.h"
#include <cstring>
#include <string>
#include <sstream>
#include <iostream>

using namespace std;

int lineno = 1;
int tokenpos = 1;

%}

escaped_char \\(a|b|t|n|v|f|r|\\|\'|\")

%%
  /*
    Pattern definitions for all tokens 
  */

for { return T_FOR; }
while { return T_WHILE; }
if { return T_IF; }
else { return T_ELSE; }
return { return T_RETURN; }
break { yylval.sval = new string("BreakStmt"); return T_BREAK; }
continue { yylval.sval = new string("ContinueStmt"); return T_CONTINUE; }

var                        { return T_VAR; }
int                        { yylval.sval = new string("IntType"); return T_INTTYPE; }
bool                        { yylval.sval = new string("BoolType"); return T_BOOLTYPE; }
\;                         { return T_SEMICOLON; }
\,                         { return T_COMMA; }
\[                         { return T_LSB; }
\]                         { return T_RSB; }
\=                         { return T_ASSIGN; }
\;                         { return T_SEMICOLON; }
\'([^'\\\n]|{escaped_char})\' { yylval.sval = new string(yytext); return T_CHARCONSTANT; }
\"([ -\!\#-\[\]-~]|\\(n|r|t|v|f|a|b|\\|\'|\"))*\" { yylval.sval = new string(yytext); return T_STRINGCONSTANT; }
([0-9]+)|(0(x|X)[0-9a-fA-F]+) { yylval.sval = new string(yytext); return T_INTCONSTANT; }
true {yylval.sval = new string("True"); return T_TRUE;}
false {yylval.sval = new string("False"); return T_FALSE;}

\+                         { yylval.sval = new string("Plus"); return T_PLUS; }
\-                         { yylval.sval = new string("Minus"); return T_MINUS; }
\/                         { yylval.sval = new string("Div"); return T_DIV; }
\*                         { yylval.sval = new string("Mult"); return T_MULT; }
\%                         { yylval.sval = new string("Mod"); return T_MOD; }
\!                         { yylval.sval = new string("Not"); return T_NOT; }
\=\=                       { yylval.sval = new string("Eq"); return T_EQ; }
\!\=                       { yylval.sval = new string("Neq"); return T_NEQ; }
\<\<                       { yylval.sval = new string("Leftshift"); return T_LEFTSHIFT; }
\>\>                       { yylval.sval = new string("Rightshift"); return T_RIGHTSHIFT; }
\<\=                       { yylval.sval = new string("Leq"); return T_LEQ; }
\>\=                       { yylval.sval = new string("Geq"); return T_GEQ; }
\<                         { yylval.sval = new string("Lt"); return T_LT; }
\>                         { yylval.sval = new string("Gt"); return T_GT; }
\&\&                       { yylval.sval = new string("And"); return T_AND; }
\|\|                       { yylval.sval = new string("Or"); return T_OR; }


string { yylval.sval = new string("StringType"); return T_STRINGTYPE; }
\( { return T_LPAREN; }
\) { return T_RPAREN; }
func { return T_FUNC; }
extern { return T_EXTERN; }
void { yylval.sval = new string("VoidType"); return T_VOID; }


func { return T_FUNC; }


package                    { return T_PACKAGE; }
\{                         { return T_LCB; }
\}                         { return T_RCB; }
[a-zA-Z\_][a-zA-Z\_0-9]*   { yylval.sval = new string(yytext); return T_ID; } /* note that identifier pattern must be after all keywords */
[\t\r\n\a\v\b ]+           { } /* ignore whitespace */
.                          { cerr << "Error: unexpected character in input" << endl; return -1; }

%%

int yyerror(const char *s) {
  cerr << lineno << ": " << s << " at char " << tokenpos << endl;
  return 1;
}

