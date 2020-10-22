
#include "default-defs.h"
#include <list>
#include <ostream>
#include <iostream>
#include <sstream>

#ifndef YYTOKENTYPE
#include "decafast.tab.h"
#endif

using namespace std;

/// decafAST - Base class for all abstract syntax tree nodes.
class decafAST {
public:
  virtual ~decafAST() {}
  virtual string str() { return string(""); }
};

string getString(decafAST *d) {
	if (d != NULL) {
		return d->str();
	} else {
		return string("None");
	}
}

template <class T>
string commaList(list<T> vec) {
    string s("");
    for (typename list<T>::iterator i = vec.begin(); i != vec.end(); i++) { 
        s = s + (s.empty() ? string("") : string(",")) + (*i)->str(); 
    }   
    if (s.empty()) {
        s = string("None");
    }   
    return s;
}

string ctoi(string str)
{
  if(str.empty())
  {
    return str;
  }
  int val = 0;
  stringstream s;
  if(str[1] != '\\')
  {
    val = int(str[1]);
  } 
  else
  {
    switch(str[2])
    {
     
    case 'a': val = 7; break;
    case 'b': val = 8; break;
    case 't': val = 9; break;
    case 'n': val = 10; break;
    case 'v': val = 11; break;
    case 'f': val = 12; break;
    case 'r': val = 13; break;
    case '\\': val = 92; break;
    case '\'': val = 39; break;
    case '\"': val = 34; break;
    }
  }
  s << val;
  return string(s.str());
}

class decafStr : public decafAST {
	string Input;
public:
	decafStr(string input) : Input(input) {}
	string str() { return string(Input); }
};

/// decafStmtList - List of Decaf statements
class decafStmtList : public decafAST {
	list<decafAST *> stmts;
public:
	decafStmtList() {}
	~decafStmtList() {
		for (list<decafAST *>::iterator i = stmts.begin(); i != stmts.end(); i++) { 
			delete *i;
		}
	}
	int size() { return stmts.size(); }
	void push_front(decafAST *e) { stmts.push_front(e); }
	void push_back(decafAST *e) { stmts.push_back(e); }
	string str() { return commaList<class decafAST *>(stmts); }
};

class PackageAST : public decafAST {
	string Name;
	decafStmtList *FieldDeclList;
	decafStmtList *MethodDeclList;
public:
	PackageAST(string name, decafStmtList *fieldlist, decafStmtList *methodlist) 
		: Name(name), FieldDeclList(fieldlist), MethodDeclList(methodlist) {}
	~PackageAST() { 
		if (FieldDeclList != NULL) { delete FieldDeclList; }
		if (MethodDeclList != NULL) { delete MethodDeclList; }
	}
	string str() { 
		return string("Package") + "(" + Name + "," + getString(FieldDeclList) + "," + getString(MethodDeclList) + ")";
	}
};

/// ProgramAST - the decaf program
class ProgramAST : public decafAST {
	decafStmtList *ExternList;
	PackageAST *PackageDef;
public:
	ProgramAST(decafStmtList *externs, PackageAST *c) : ExternList(externs), PackageDef(c) {}
	~ProgramAST() { 
		if (ExternList != NULL) { delete ExternList; } 
		if (PackageDef != NULL) { delete PackageDef; }
	}
	string str() { return string("Program") + "(" + getString(ExternList) + "," + getString(PackageDef) + ")"; }
};

class ExternFunctionAST : public decafAST {
	string Name;
	string ReturnType;
	decafStmtList *ParameterTypeList;
public:
	ExternFunctionAST(string name, string type, decafStmtList *types) : Name(name), ReturnType(type), ParameterTypeList(types) {}
	string str() {
		return string("ExternFunction") + "(" + Name + "," + ReturnType + "," + getString(ParameterTypeList) + ")";
	}
};

class VarDefAST : public decafAST {
	string Type;
public:
	VarDefAST(string type) : Type(type) {}
	string str() {
		return string("VarDef") + "(" + Type + ")";
	}
};

class FieldDeclAST : public decafAST {
	string Name;
	string Type;
	string Extra;
	bool isAssignmnet;
public:
	FieldDeclAST(string name, string type, string extra, bool assignment) : Name(name), Type(type), Extra(extra), isAssignmnet(assignment) {}
	string str() {
		if (isAssignmnet) {
			return string("AssignGlobalVar") + "(" + Name + "," + Type + "," + Extra + ")";
		}
		else {
			return string("FieldDecl") + "(" + Name + "," + Type + "," + Extra + ")";
		}
	}
};

class ConstantAST : public decafAST {
	string Value;
	bool isNum;
public:
	ConstantAST(string value, bool is) : Value(value), isNum(is) {}
	string str() {
		if(isNum) {
			return string("NumberExpr") + "(" + Value + ")";
		}
		else {
			return string("BoolExpr") + "(" + Value + ")";
		}
	}
};

class MethodDeclAST : public decafAST {
	string Name;
	string ReturnType;
	decafStmtList *ParameterList;
	decafStmtList *MethodBlock;
public:
	MethodDeclAST(string name, string type, decafStmtList *params, decafStmtList *block) : Name(name), ReturnType(type), ParameterList(params), MethodBlock(block) {}
	string str() {
		return string("Method") + "(" + Name + "," + ReturnType + "," + getString(ParameterList) + "," + getString(MethodBlock) + ")";
	}
};

class MethodVarDefAST : public decafAST {
	string Name;
	string Type;
public:
	MethodVarDefAST(string name, string type) : Name(name), Type(type) {}
	string str() {
		return string("VarDef") + "(" + Name + "," + Type + ")";
	}
};

class MethodBlockAST : public decafAST {
	decafStmtList *VarDecList;
	decafStmtList *StmtList;
public:
	MethodBlockAST(decafStmtList *vdL, decafStmtList *stL) : VarDecList(vdL), StmtList(stL) {}
	string str() {
			return string("MethodBlock") + "(" + getString(VarDecList) + "," + getString(StmtList) + ")";
	}
};

class BlockAST : public decafAST {
	decafStmtList *VarDecList;
	decafStmtList *StmtList;
public:
	BlockAST(decafStmtList *vdL, decafStmtList *stL) : VarDecList(vdL), StmtList(stL) {}
	string str() {
		return string("Block") + "(" + getString(VarDecList) + "," + getString(StmtList) + ")";
	}
};

class AssignAST : public decafAST {
	string Name;
	string Value;
public:
	AssignAST(string name, string value) : Name(name), Value(value) {}
	string str() {
		return string("AssignVar") + "(" + Name + "," + Value + ")";
	}
};

class IfAST : public decafAST {
	decafAST *Condition;
	decafStmtList *If_Block;
	decafStmtList *Else_Block;
public:
	IfAST(decafAST *cond, decafStmtList *ifblock, decafStmtList *elseblock) : Condition(cond), If_Block(ifblock), Else_Block(elseblock) {}
	string str() {
		return string("IfStmt") + "(" + getString(Condition) + "," + getString(If_Block) + "," + getString(Else_Block) + ")";
	}
};

class WhileAST : public decafAST {
	decafAST *Condition;
	decafStmtList *Block;
public:
	WhileAST(decafAST *cond, decafStmtList *block) : Condition(cond), Block(block) {}
	string str() {
		return string("WhileStmt") + "(" + getString(Condition) + "," + getString(Block) + ")";
	}
};

class ForAST : public decafAST {
	decafStmtList *PreAssignList;
	decafAST *Condition;
	decafStmtList *LoopAssignList;
	decafAST *Block;
public:
	ForAST(decafStmtList *pre, decafAST *cond, decafStmtList *loop, decafAST *b) : PreAssignList(pre), Condition(cond), LoopAssignList(loop), Block(b) {}
	string str() {
		return string("ForStmt") + "(" + getString(PreAssignList) + "," + getString(Condition) + "," + getString(LoopAssignList) + "," + getString(Block) + ")";
	}
};

class ReturnAST : public decafAST {
	decafStmtList *Expr;
public:
	ReturnAST(decafStmtList *expr) : Expr(expr) {}
	string str() {
		return string("ReturnStmt") + "(" + getString(Expr) + ")";
	}
};

class BinaryExpr : public decafAST {
	string BinaryOperator;
	decafAST *LeftValue;
	decafAST *RightValue;
public:
	BinaryExpr(string op, decafAST *l, decafAST *r) : BinaryOperator(op), LeftValue(l), RightValue(r) {}
	string str() {
		return string("BinaryExpr") + "(" + BinaryOperator + "," + getString(LeftValue) + "," + getString(RightValue) + ")";
	}
};

class UnaryExpr : public decafAST {
	string UnaryOperator;
	decafAST *Expr;
public:
	UnaryExpr(string op, decafAST *e) : UnaryOperator(op), Expr(e){}
	string str() {
		return string("UnaryExpr") + "(" + UnaryOperator + "," + getString(Expr) + ")";
	}
};

class MethodCallAST : public decafAST {
	string Name;
	decafStmtList *StmtList;
public:
	MethodCallAST(string name, decafStmtList *stL) : Name(name), StmtList(stL) {}
	string str() {
		return string("MethodCall") + "(" + Name + "," + getString(StmtList) + ")";
	}
};