
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
