
%{

#include <iostream>
#include <cstdlib>


using namespace std;

int line = 1;
int col = 1;

%}

escaped_char \\(a|b|t|n|v|f|r|\\|\'|\")

%%
	/*
		Pattern definitions for all tokens
	*/
bool					{ return 1; }
break					{ return 2; }  
continue				{ return 3; }
else					{ return 4; }
extern					{ return 5; }
false					{ return 6; }
for					{ return 7; }
func					{ return 8; }
if					{ return 9; }
int					{ return 10; }
null					{ return 11; }
package				{ return 12; }
return					{ return 13; }
string					{ return 14; }
true					{ return 15; }
var					{ return 16; }
void					{ return 17; }
while					{ return 18; }

\+					{ return 19; }
\-					{ return 20; }
\*					{ return 21; }
\/					{ return 22; }
\%					{ return 23; }

\<					{ return 24; }
\<\=					{ return 25; }
\>					{ return 26; }
\>\=					{ return 27; }
\=\=					{ return 28; }
\!\=					{ return 29; }

\&\&					{ return 30; }
\|\|					{ return 31; }
\!					{ return 32; }

\<\<					{ return 33; }
\>\>					{ return 34; }

\=					{ return 35; }

\;					{ return 36; }	
\,					{ return 37; }
\.					{ return 38; }
\{					{ return 39; }
\}					{ return 40; }
\(					{ return 41; }
\)					{ return 42; }
\[					{ return 43; }
\]					{ return 44; }
	
[\t\r\a\v\b\n ]+			{ return 45; }
\/\/.*\n				{ return 46; }
([0-9]+)|(0(x|X)[0-9a-fA-F]+)		{ return 47; }
\'([^'\\\n]|{escaped_char})\'		{ return 48; }
\"([^"\\\n]|{escaped_char})*\"	{ return 49; }
[a-zA-Z\_][a-zA-Z\_0-9]*		{ return 50; }

\"([^"\\\n]|\\.)*\"			{ cerr << "Error: unknown escape sequence in string constant\n"	<< "Lexical error: line " << line << " position " << col << endl; return -1; }
\"([^"]|\n)*\"				{ cerr << "Error: newline in string constant\n"			<< "Lexical error: line " << line << " position " << col << endl; return -1; }
\"					{ cerr << "Error: string constant is missing closing delimiter\n"	<< "Lexical error: line " << line << " position " << col << endl; return -1; }
\'([^'\\\n]|{escaped_char})+\'	{ cerr << "Error: char constant length is greater than one\n"	<< "Lexical error: line " << line << " position " << col << endl; return -1; }
\'					{ cerr << "Error: unterminated char constant\n"			<< "Lexical error: line " << line << " position " << col << endl; return -1; }
\'\'					{ cerr << "Error: char constant has zero width\n"			<< "Lexical error: line " << line << " position " << col << endl; return -1; }
.					{ cerr << "Error: unexpected character in input\n"			<< "Lexical error: line " << line << " position " << col << endl; return -1; }

%%

int main () {
  int token;
  string lexeme;
  while ((token = yylex())) {
    if (token > 0) {
      lexeme.assign(yytext);
      switch(token) {
      
      	case 1: cout << "T_BOOLTYPE "		<< lexeme << endl; col += lexeme.length(); break;
	case 2: cout << "T_BREAK "		<< lexeme << endl; col += lexeme.length(); break;
	case 3: cout << "T_CONTINUE "		<< lexeme << endl; col += lexeme.length(); break;
	case 4: cout << "T_ELSE "		<< lexeme << endl; col += lexeme.length(); break;
	case 5: cout << "T_EXTERN "		<< lexeme << endl; col += lexeme.length(); break;
	case 6: cout << "T_FALSE "		<< lexeme << endl; col += lexeme.length(); break;
	case 7: cout << "T_FOR "		<< lexeme << endl; col += lexeme.length(); break;
	case 8: cout << "T_FUNC "		<< lexeme << endl; col += lexeme.length(); break;
	case 9: cout << "T_IF "		<< lexeme << endl; col += lexeme.length(); break;
	case 10: cout << "T_INTTYPE "		<< lexeme << endl; col += lexeme.length(); break;
	case 11: cout << "T_NULL "		<< lexeme << endl; col += lexeme.length(); break;
	case 12: cout << "T_PACKAGE "		<< lexeme << endl; col += lexeme.length(); break;
	case 13: cout << "T_RETURN "		<< lexeme << endl; col += lexeme.length(); break;
	case 14: cout << "T_STRINGTYPE "	<< lexeme << endl; col += lexeme.length(); break;
	case 15: cout << "T_TRUE "		<< lexeme << endl; col += lexeme.length(); break;
	case 16: cout << "T_VAR "		<< lexeme << endl; col += lexeme.length(); break;
	case 17: cout << "T_VOID "		<< lexeme << endl; col += lexeme.length(); break;
	case 18: cout << "T_WHILE "		<< lexeme << endl; col += lexeme.length(); break;
	case 19: cout << "T_PLUS "		<< lexeme << endl; col += lexeme.length(); break;
	case 20: cout << "T_MINUS "		<< lexeme << endl; col += lexeme.length(); break;
	case 21: cout << "T_MULT "		<< lexeme << endl; col += lexeme.length(); break;
	case 22: cout << "T_DIV "		<< lexeme << endl; col += lexeme.length(); break;
	case 23: cout << "T_MOD "		<< lexeme << endl; col += lexeme.length(); break;
	case 24: cout << "T_LT "		<< lexeme << endl; col += lexeme.length(); break;
	case 25: cout << "T_LEQ "		<< lexeme << endl; col += lexeme.length(); break;
	case 26: cout << "T_GT "		<< lexeme << endl; col += lexeme.length(); break;
	case 27: cout << "T_GEQ "		<< lexeme << endl; col += lexeme.length(); break;
	case 28: cout << "T_EQ "		<< lexeme << endl; col += lexeme.length(); break;
	case 29: cout << "T_NEQ "		<< lexeme << endl; col += lexeme.length(); break;
	case 30: cout << "T_AND "		<< lexeme << endl; col += lexeme.length(); break;
	case 31: cout << "T_OR "		<< lexeme << endl; col += lexeme.length(); break;
	case 32: cout << "T_NOT "		<< lexeme << endl; col += lexeme.length(); break;
	case 33: cout << "T_LEFTSHIFT "	<< lexeme << endl; col += lexeme.length(); break;
	case 34: cout << "T_RIGHTSHIFT "	<< lexeme << endl; col += lexeme.length(); break;
	case 35: cout << "T_ASSIGN "		<< lexeme << endl; col += lexeme.length(); break;
	case 36: cout << "T_SEMICOLON "	<< lexeme << endl; col += lexeme.length(); break;
	case 37: cout << "T_COMMA " 		<< lexeme << endl; col += lexeme.length(); break;
	case 38: cout << "T_DOT "		<< lexeme << endl; col += lexeme.length(); break;
	case 39: cout << "T_LCB "		<< lexeme << endl; col += lexeme.length(); break;
	case 40: cout << "T_RCB "		<< lexeme << endl; col += lexeme.length(); break;
	case 41: cout << "T_LPAREN "		<< lexeme << endl; col += lexeme.length(); break;
	case 42: cout << "T_RPAREN "		<< lexeme << endl; col += lexeme.length(); break;
	case 43: cout << "T_LSB "		<< lexeme << endl; col += lexeme.length(); break;
	case 44: cout << "T_RSB "		<< lexeme << endl; col += lexeme.length(); break;
	case 45: 
		{
			cout << "T_WHITESPACE ";
			for (int i = 0; i < lexeme.length(); i++) {
				if (lexeme[i] == '\n') {
					cout << "\\n";
					line++;
					col = 1;
				}
				else{
					cout << lexeme[i];
					col++;
				}
			}
			cout << endl;
			break;
		}
	case 46:
		{
			cout << "T_COMMENT ";
			for (int i = 0; i < lexeme.length(); i++) {
				if (lexeme[i] == '\n') {
					cout << "\\n";
					line++;
					col = 1;
				}
				else{
					cout << lexeme[i];
					col++;
				}
			}
			cout << endl;
			break;
		}
	case 47: cout << "T_INTCONSTANT "	<< lexeme << endl; col += lexeme.length(); break;
	case 48: cout << "T_CHARCONSTANT "	<< lexeme << endl; col += lexeme.length(); break;
	case 49: cout << "T_STRINGCONSTANT "	<< lexeme << endl; col += lexeme.length(); break;
	case 50: cout << "T_ID "		<< lexeme << endl; col += lexeme.length(); break;
	default: exit(EXIT_FAILURE);
      }
    } else {
      if (token < 0) {
        exit(EXIT_FAILURE);
      }
    }
  }
  exit(EXIT_SUCCESS);
}
