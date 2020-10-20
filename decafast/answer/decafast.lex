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

var                        { return T_VAR; }
int                        { yylval.sval = new string(yytext); return T_INTTYPE; }
bool                        { yylval.sval = new string(yytext); return T_BOOLTYPE; }
\;                         { return T_SEMICOLON; }
\,                         { return T_COMMA; }
\[                         { return T_LSB; }
\]                         { return T_RSB; }
\=                         { return T_ASSIGN; }
\;                         { return T_SEMICOLON; }
\'([^'\\\n]|{escaped_char})\' { yylval.sval = new string(yytext); return T_CHARCONSTANT; }
([0-9]+)|(0(x|X)[0-9a-fA-F]+) { yylval.sval = new string(yytext); return T_INTCONSTANT; }
true {yylval.sval = new string(yytext); return T_TRUE;}
false {yylval.sval = new string(yytext); return T_FALSE;}

string { yylval.sval = new string(yytext); return T_STRING; }
\( { return T_LPAREN; }
\) { return T_RPAREN; }
func { return T_FUNC; }
extern { return T_EXTERN; }
void { yylval.sval = new string(yytext); return T_VOID; }

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

