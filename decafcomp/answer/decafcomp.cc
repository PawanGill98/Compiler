
#include "decafcomp-defs.h"
#include <algorithm>
#include <list>
#include <ostream>
#include <iostream>
#include <sstream>

#ifndef YYTOKENTYPE
#include "decafcomp.tab.h"
#endif

using namespace std;

symbol_table_list symtbl;

static llvm::AllocaInst *CreateEntryBlockAlloca(llvm::Function *TheFunction,
                                          const std::string &VarName, llvm::Type *type) {
  llvm::IRBuilder<> TmpB(&TheFunction->getEntryBlock(),
                   TheFunction->getEntryBlock().begin());
  return TmpB.CreateAlloca(type, nullptr, VarName);
}

llvm::Constant *getZeroInit(string type)
{
  llvm::Constant *Init;
  if(type == "IntType")         
  { Init = Builder.getInt32(0); } // 32 bit int
  else if(type == "BoolType")  
  { Init = Builder.getInt1(0); } // 1 bit int  
  else 
  { Init = NULL; } // void 
  return Init;
}

llvm::Type* getLLVMType(string type)
{
  llvm::Type* LType;
  if(type == "IntType")         
  { LType = Builder.getInt32Ty();  } // 32 bit int
  else if(type == "BoolType")  
  { LType = Builder.getInt1Ty();   } // 1 bit int  
  else if(type == "VoidType")  
  { LType = Builder.getVoidTy();   } // void 
  else if(type == "StringType") 
  { LType = Builder.getInt8PtrTy();} // ptr to array of bytes
  return LType;
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
	//val = 120;
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

llvm::Function *genPrintIntDef() {
  // create a extern definition for print_int
  std::vector<llvm::Type*> args;
  args.push_back(Builder.getInt32Ty()); // print_int takes one i32 argument
  return llvm::Function::Create(llvm::FunctionType::get(Builder.getVoidTy(), args, false), llvm::Function::ExternalLinkage, "print_int", TheModule);
}

descriptor* access_symtbl(string id)
{
  for(symbol_table_list::iterator i = symtbl.begin(); i != symtbl.end(); ++i)
  {
    symbol_table::iterator find_id;
    if((find_id = i->find(id)) != i->end())
    {
      return find_id->second; // second refers to descriptor* in map<string, descriptor*> 
    }
  } 
  return NULL;
}

/// decafAST - Base class for all abstract syntax tree nodes.
class decafAST {
public:
  virtual ~decafAST() {}
  virtual string str() { return string(""); }
  virtual llvm::Value *Codegen() = 0;
};

string getString(decafAST *d) {
	if (d != NULL) {
		return d->str();
	} else {
		return string("None");
	}
}

class decafStr : public decafAST {
	string Input;
public:
	decafStr(string input) : Input(input) {}
	string str() { return string(Input); }
	llvm::Value *Codegen() { 
		return NULL;
	}
};

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

template <class T>
llvm::Value *listCodegen(list<T> vec) {
	llvm::Value *val = NULL;
	for (typename list<T>::iterator i = vec.begin(); i != vec.end(); i++) { 
		llvm::Value *j = (*i)->Codegen();
		if (j != NULL) { val = j; }
	}	
	return val;
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
	list<decafAST*> return_list() {
		return stmts;
	}
	int size() { return stmts.size(); }
	void push_front(decafAST *e) { stmts.push_front(e); }
	void push_back(decafAST *e) { stmts.push_back(e); }
	string str() { return commaList<class decafAST *>(stmts); }
	llvm::Value *Codegen() { 
		return listCodegen<decafAST *>(stmts); 
	}
};



class ExternVarDefAST : public decafAST {
	string Type;
public:
	ExternVarDefAST(string type) : Type(type) {}
	string str() {
		return string("VarDef") + "(" + Type + ")";
	}
	string getVarType() {
		return Type;
	}
	llvm::Value *Codegen(){
		return NULL;
	}
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
	llvm::Value *Codegen(){
		llvm::Type *returnTy = getLLVMType(ReturnType);
		std::vector<llvm::Type*> args;
		if(ParameterTypeList != NULL){
			list<decafAST*> stmts = ParameterTypeList->return_list();
			for (list<decafAST *>::iterator i = stmts.begin(); i != stmts.end(); i++) { 
				llvm::Type *type = getLLVMType(((ExternVarDefAST*)(*i))->getVarType());
				args.push_back(type);
			}
		}
		llvm::Function *func = llvm::Function::Create(
			llvm::FunctionType::get(returnTy, args, false),
			llvm::Function::ExternalLinkage,
			Name,
			TheModule);
										
		descriptor* d = new descriptor;
    	d->type = ReturnType;
    	d->func_ptr = func;
    	d->arg_types = args;
    	(symtbl.front())[Name] = d;
		return func;
	}
};

llvm::Constant* getLLVMDefaultValue(string type)
{
	llvm::Constant *value;
	if(type == "IntType")         
	{ value = Builder.getInt32(0);  } // 32 bit int
	if(type == "BoolType")  
	{ value = Builder.getInt1(0);   } // 1 bit int
	return value;
}

llvm::Value* getLLVMDefaultReturn(string returnType)
{
	if(returnType == "IntType"){
		return Builder.CreateRet(Builder.getInt32(0));
	}
	else if(returnType == "BoolType"){
		return Builder.CreateRet(Builder.getInt1(0));
	}
	else if((returnType == "VoidType") /*|| returnType == ""*/){
		return Builder.CreateRet(nullptr);
	}
	return NULL;
}

class FieldDeclScalarAST : public decafAST {
	string Name;
	string Type;
public:
	FieldDeclScalarAST(string name, string type) : Name(name), Type(type) {}
	string str() {
		return string("FieldDecl") + "(" + Name + "," + Type + "," + "Scalar" + ")";
	}
	llvm::Value *Codegen(){
		llvm::Type *returnTy = getLLVMType(Type);
		llvm::Constant *defaultVal = getLLVMDefaultValue(Type);
		llvm::GlobalVariable *gloabalVar = new llvm::GlobalVariable(
			*TheModule, 
			returnTy,
			false,  // variable is mutable
			llvm::GlobalValue::InternalLinkage, 
			defaultVal, 
			Name
		);

		descriptor* d = new descriptor;
		d->global_ptr = gloabalVar;
		d->alloca_ptr = NULL;
		(symtbl.front())[Name] = d;
		return gloabalVar;
	}
};

class FieldDeclArrayAST : public decafAST {
	string Name;
	string Type;
	string Size;
public:
	FieldDeclArrayAST(string name, string type, string size) : Name(name), Type(type), Size(size) {}
	string str() {
		return string("FieldDecl") + "(" + Name + "," + Type + "," + Size + ")";
	}
	llvm::Value *Codegen(){
		int size = atoi(Size.c_str());
		// array size = size
		llvm::ArrayType *arrayi32 = llvm::ArrayType::get(Builder.getInt32Ty(), size);
		// zeroinitalizer: initialize array to all zeroes
		llvm::Constant *zeroInit = llvm::Constant::getNullValue(arrayi32);
		// declare a global variable
		llvm::GlobalVariable *gloabalVar = new llvm::GlobalVariable(*TheModule, arrayi32, false, llvm::GlobalValue::ExternalLinkage, zeroInit, Name);
		// 3rd parameter to GlobalVariable is false because it is not a constant variable

		descriptor* d = new descriptor;
		d->global_ptr = gloabalVar;
		d->alloca_ptr = NULL;
		(symtbl.front())[Name] = d;
		return gloabalVar;
	}
};

class ConstantAST : public decafAST {
	string Value;
	bool isNum;
	int num_val = 0;
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
	int getVal(){
		num_val = atoi(Value.c_str());
		return num_val;
	}
	string getID() { return Value; }
	llvm::Constant *Codegen(){
		llvm::Constant *val;
		if(isNum) {
			int num;
			num = atoi(Value.c_str());
			for(int i = 0; i < Value.size(); i++) {
				if((Value[i] == 'x') || Value[i] == 'X') {
					const char *hexstring = Value.c_str();
					num = (int)strtol(hexstring, NULL, 16);
				}
			}
			val = Builder.getInt32(num);
			return val;
		}
		else {
			if(Value == "True" ) { val = Builder.getInt1(1);}
			if(Value == "False") { val = Builder.getInt1(0);}
			return val;
		}
	}
};

class ConstantNumberExprAST : public decafAST {
	string Value;
public:
	ConstantNumberExprAST(string value) : Value(value) {}
	string str() {
		return string("NumberExpr") + "(" + Value + ")";
	}
	int getVal(){
		int num_val = atoi(Value.c_str());
		return num_val;
	}
	string getID() { return Value; }
	llvm::Value *Codegen(){
		llvm::Value *val;
			int num;
			num = atoi(Value.c_str());
			for(int i = 0; i < Value.size(); i++) {
				if((Value[i] == 'x') || Value[i] == 'X') {
					const char *hexstring = Value.c_str();
					num = (int)strtol(hexstring, NULL, 16);
					break;
				}
			}
			val = Builder.getInt32(num);
			return val;
	}
};

class ConstantBoolExprAST : public decafAST {
	string Value;
public:
	ConstantBoolExprAST(string value) : Value(value) {}
	string str() {
		return string("BoolExpr") + "(" + Value + ")";
	}
	int getVal(){
		int num_val = atoi(Value.c_str());
		return num_val;
	}
	string getID() { return Value; }
	llvm::Value *Codegen(){
		llvm::Value *val;
		if(Value == "True" ) { val = Builder.getInt1(1);}
		if(Value == "False") { val = Builder.getInt1(0);}
		return val;
	}
};

class FieldDeclAssignAST : public decafAST {
	string Name;
	string Type;
	decafAST *Constant;
public:
	FieldDeclAssignAST(string name, string type, decafAST *constant) : Name(name), Type(type), Constant(constant) {}
	string str() {
		return string("AssignGlobalVar") + "(" + Name + "," + Type + "," + getString(Constant) + ")";
	}
	llvm::Value *Codegen(){
		llvm::Type *returnTy = getLLVMType(Type);
		llvm::Value *value = Constant->Codegen();
		llvm::GlobalVariable *gloabalVar = new llvm::GlobalVariable(
			*TheModule, 
			returnTy, 
			false,  // variable is mutable
			llvm::GlobalValue::InternalLinkage, 
			(llvm::Constant *)value,
			Name);

		descriptor* d = new descriptor;
		d->global_ptr = gloabalVar;
		d->alloca_ptr = NULL;
		(symtbl.front())[Name] = d;
		return gloabalVar;
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
	llvm::Value *Codegen(){
		symbol_table syms;
		symtbl.push_front(syms);
		if(VarDecList != NULL) { VarDecList->Codegen(); }
		if(StmtList != NULL) { StmtList->Codegen();    }
		symtbl.pop_front();
		return NULL;
	}
};

class MethodBlockAST : public decafAST {
	string Name;
	string ReturnType;
	std::vector<string> arg_names;
	decafStmtList *VarDecList;
	decafStmtList *StmtList;
public:
	MethodBlockAST(decafStmtList *vdL, decafStmtList *stL) : VarDecList(vdL), StmtList(stL) {}
	string str() {
			return string("MethodBlock") + "(" + getString(VarDecList) + "," + getString(StmtList) + ")";
	}
	void setName(string name) {
		Name = name;
	}
	void setReturn(string returnTy) {
		ReturnType = returnTy;
	}
	string getReturn() {
		return ReturnType;
	}
	void setArgs(std::vector<string> args) {
		arg_names = args;
	}
	llvm::Value *Codegen(){
		symbol_table syms;
		symtbl.push_front(syms);
		if(VarDecList != NULL) { VarDecList->Codegen(); }
		if(StmtList != NULL) { StmtList->Codegen();    }
		getLLVMDefaultReturn(ReturnType);
		symtbl.pop_front();
		return NULL;
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
	string getVarType() {
		return Type;
	}
	string getVarName() {
		return Name;
	}
	llvm::Value *Codegen(){
		if(Name.empty()) { return NULL; }

		llvm::Type *type = getLLVMType(Type);
		llvm::AllocaInst *Alloca = NULL;

		Alloca = Builder.CreateAlloca(type, 0, Name);
		
		descriptor* d = new descriptor;
		d->type = Type;
		d->alloca_ptr = Alloca;
		d->global_ptr = NULL;
		(symtbl.front())[Name] = d;
		return NULL;
	}
};

class MethodDeclAST : public decafAST {
	string Name;
	string ReturnType;
	llvm::Function *func_ptr;
	llvm::BasicBlock *basic_b;
	decafStmtList *ParameterList;
	MethodBlockAST *MethodBlock;
public:
	MethodDeclAST(string name, string type, decafStmtList *params, MethodBlockAST *block) : Name(name), ReturnType(type), ParameterList(params), MethodBlock(block) {}
	string str() {
		return string("Method") + "(" + Name + "," + ReturnType + "," + getString(ParameterList) + "," + getString(MethodBlock) + ")";
	}
	void set_ptr(llvm::Function *ptr) {
		func_ptr = ptr;
	}
	void set_BB(llvm::BasicBlock *bb) {
		basic_b = bb;
	}
	void back() {
		Builder.SetInsertPoint(basic_b);
		if(MethodBlock != NULL) { MethodBlock->Codegen(); }
	}
	llvm::Value *Codegen(){
		MethodBlock->setReturn(ReturnType);
		llvm::Value *val;
		llvm::Type *returnTy = getLLVMType(ReturnType);

		// fill up the args vector with types
		std::vector<llvm::Type*> args;
		std::vector<string> arg_names;
		list<decafAST*> stmts;
		if(ParameterList != NULL){
			stmts = ParameterList->return_list();
			for (list<decafAST *>::iterator i = stmts.begin(); i != stmts.end(); i++) { 
				llvm::Type *type = getLLVMType(((MethodVarDefAST*)(*i))->getVarType());
				string name = ((MethodVarDefAST*)(*i))->getVarName();
				args.push_back(type);
				arg_names.push_back(name);
			}
		}

		llvm::FunctionType *FT = llvm::FunctionType::get(returnTy, args, false);
		llvm::Function *TheFunction = llvm::Function::Create(FT, llvm::Function::ExternalLinkage, Name, TheModule);

		descriptor* d = new descriptor;
		d->type       = ReturnType;
		d->func_ptr   = TheFunction;
		d->arg_types  = args;
		(symtbl.front())[Name] = d;

		llvm::BasicBlock *BB = llvm::BasicBlock::Create(TheContext, "entry", TheFunction);
		set_BB(BB);
		Builder.SetInsertPoint(BB);
		
		int idx = 0;
		for (auto &Arg : TheFunction->args()) {
			llvm::AllocaInst *Alloca = CreateEntryBlockAlloca(TheFunction, arg_names[idx], Arg.getType());

			const llvm::PointerType *ptrTy = Arg.getType()->getPointerTo();
			if(ptrTy == Alloca->getType()){
				val = Builder.CreateStore(&Arg, Alloca);
			}

			descriptor* d = new descriptor;
			d->alloca_ptr = Alloca;
			d->global_ptr = NULL;
			string st = arg_names[idx];
			idx++;
			(symtbl.front())[st] = d; 
		}

		set_ptr(TheFunction);
		return TheFunction;

	}
};

class MethodCallAST : public decafAST
{
  string Name;
  decafStmtList *ArgList;
public: 
	MethodCallAST(string name, decafStmtList *alist) : Name(name), ArgList(alist) {}  
	~MethodCallAST() {
		if(ArgList != NULL) { delete ArgList; }
	}
	string str() {
		return string("MethodCall") + "(" + Name + "," + getString(ArgList) +")"; 
	}
	llvm::Value *Codegen() {
        llvm::Function *call = (access_symtbl(Name))->func_ptr;			
		bool isVoid = call->getReturnType()->isVoidTy();

		llvm::Value* val = NULL;
		std::vector<llvm::Value*> args;
		list<decafAST*> stmts;
		if(ArgList != NULL){
			stmts = ArgList->return_list();
			for (list<decafAST *>::iterator i = stmts.begin(); i != stmts.end(); i++) { 
				llvm::Value *value = (*i)->Codegen();
				args.push_back(value);
			}
			int idx = 0;
			for(auto arg = call->arg_begin(); arg != call->arg_end(); ++arg, idx++)
				if(arg->getType()->isIntegerTy(32) && args[idx]->getType()->isIntegerTy(1)) {
					llvm::Value *value = Builder.CreateZExt(args[idx], Builder.getInt32Ty(), "zexttmp");
					args[idx] = value;
				}
		}
	
		val = Builder.CreateCall(call, args, isVoid ? "" : "calltmp"); 
		return val;
	}
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
	llvm::Value *Codegen() { 
		llvm::Value *val = NULL;
		TheModule->setModuleIdentifier(llvm::StringRef(Name)); 
		if (NULL != FieldDeclList) {
			val = FieldDeclList->Codegen();
		}
		if (NULL != MethodDeclList) {
			val = MethodDeclList->Codegen();

			list<decafAST*>stmts = MethodDeclList->return_list();
			for (list<decafAST*>::iterator i = stmts.begin(); i != stmts.end(); i++) {   
				MethodDeclAST* e = (MethodDeclAST*)(*i);
				e->back();
			}

		} 
		// Q: should we enter the class name into the symbol table?
		return val; 
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
	llvm::Value *Codegen() { 
		llvm::Value *val = NULL;
		if (NULL != ExternList) {
			val = ExternList->Codegen();
		}
		if (NULL != PackageDef) {
			val = PackageDef->Codegen();
		} else {
			throw runtime_error("no package definition in decaf program");
		}
		return val; 
	}
};

class ValueVariableExprAST : public decafAST
{
	string Name;
	decafStmtList* IndexExpr;
public: 
	ValueVariableExprAST(string name) : Name(name) {}
	string getID() { return Name; }
	string str() {
		return string("VariableExpr") + "(" + Name + ")";
	}
	llvm::Value *Codegen() {
		descriptor* d  = access_symtbl(Name);
		if(d != NULL) {
			if(d->alloca_ptr != NULL) {
				llvm::Value *val;
				val = Builder.CreateLoad(d->alloca_ptr);
				val->setName(Name);
				return val;
				//return Builder.CreateLoad(d->alloca_ptr);  
			}
			else if(d->global_ptr != NULL) {
				llvm::Value *val;
				val = Builder.CreateLoad(d->global_ptr);
				val->setName(Name);
				return val;
				//return Builder.CreateLoad(d->global_ptr);  
			}
		}
		return NULL; 
	}
};

class ValueArrayLocExprAST : public decafAST
{
	string Name;
	decafStmtList* IndexExpr;
public: 
	ValueArrayLocExprAST(string name, decafStmtList* index) : Name(name), IndexExpr(index) {}
	
	string getID() { return Name; }  
	decafStmtList* getIndexExpr() { return IndexExpr; }

	llvm::Value *getIndexVal() {
		llvm::Value *indexVal = IndexExpr->Codegen();
		return indexVal;
	}
	   
	string str() {
		return string("ArrayLocExpr") + "(" + Name + "," + getString(IndexExpr) +")";
	}
	llvm::Value *Codegen() {
		descriptor* d  = access_symtbl(Name);
		if(d != NULL) {
			if(d->alloca_ptr != NULL) {
				llvm::Value *val;
				val = Builder.CreateLoad(d->alloca_ptr);
				val->setName(Name);
				return val;
				//return Builder.CreateLoad(d->alloca_ptr);  
			}
			else if(d->global_ptr != NULL) {
				llvm::Value *ArrayLoc = Builder.CreateStructGEP(d->global_ptr, 0, "arrayloc");
				llvm::Value *indexVal = IndexExpr->Codegen();
				llvm::Value *Index = indexVal; // access Foo[8]
				llvm::Value *ArrayIndex = Builder.CreateGEP(ArrayLoc, Index, "arrayindex");

				llvm::Value *val;
				val = Builder.CreateLoad(ArrayIndex);
				val->setName(Name);
				return val;
				//return Builder.CreateLoad(ArrayIndex);  
			} 
		}
		return NULL;
	}
};

class AssignVarAST : public decafAST
{
	ValueVariableExprAST* Value;
	decafAST* Expr;
public: 
	AssignVarAST(ValueVariableExprAST* value, decafAST* expr) : Value(value), Expr(expr) {}
	string str() {
		return string("AssignVar") + "(" + Value->getID() + "," + getString(Expr) + ")";
	}
	string getName(){
		return Value->getID();
	}
	llvm::Value *Codegen() {
		llvm::Value *val = NULL;
		descriptor *d;
		d = access_symtbl(Value->getID());

		llvm::AllocaInst *Alloca = NULL;
		if(d != NULL){
			Alloca = d->alloca_ptr;
		}

		llvm::GlobalVariable *global = NULL;
		if(d != NULL){
			global = d->global_ptr;
		}

		llvm::Value *rvalue = Expr->Codegen();


			if(global != NULL) {
				val = Builder.CreateStore(rvalue, global);
			}
			else if(Alloca != NULL) {
				val = Builder.CreateStore(rvalue, Alloca);
			}
		return NULL;
	}
};

class AssignArrayAST : public decafAST
{
	ValueArrayLocExprAST* Value;
	decafAST* Expr;
public: 
	AssignArrayAST(ValueArrayLocExprAST* value, decafAST* expr) : Value(value), Expr(expr) {}
	string str() {
		return string("AssignArrayLoc") + "(" + Value->getID() + "," + getString(Value->getIndexExpr()) + "," + getString(Expr) + ")";
	}
	llvm::Value *Codegen() {
		descriptor *d;
		d = access_symtbl(Value->getID());

		llvm::GlobalVariable *global;
		global = d->global_ptr;

		llvm::Value *rvalue = Expr->Codegen();

		const llvm::PointerType *ptrTy = rvalue->getType()->getPointerTo();
		if(ptrTy == global->getType()){
			return NULL;
		}

		llvm::Value *val = Expr->Codegen();
		llvm::Value *indexVal = Value->getIndexVal();

		llvm::Value *ArrayLoc = Builder.CreateStructGEP(global, 0, "arrayloc");
		llvm::Value *Index = indexVal; // access Foo[8]
		llvm::Value *ArrayIndex = Builder.CreateGEP(ArrayLoc, Index, "arrayindex");
		llvm::Value *ArrayStore = Builder.CreateStore(val, ArrayIndex); // Foo[8] = 1
		return ArrayStore;
	}
};

class IfAST : public decafAST {
	decafAST *Condition;
	BlockAST *If_Block;
	BlockAST *Else_Block;
public:
	IfAST(decafAST *cond, BlockAST *ifblock, BlockAST *elseblock) : Condition(cond), If_Block(ifblock), Else_Block(elseblock) {}
	string str() {
		return string("IfStmt") + "(" + getString(Condition) + "," + getString(If_Block) + "," + getString(Else_Block) + ")";
	}
	llvm::Value *Codegen(){
		llvm::BasicBlock *CurBB = Builder.GetInsertBlock();
		llvm::Function *func = CurBB->getParent();

		llvm::BasicBlock* IfStartBB = llvm::BasicBlock::Create(TheContext, "ifstart", func);
		llvm::BasicBlock* IfTrueBB = llvm::BasicBlock::Create(TheContext, "iftrue",  func);
		llvm::BasicBlock* IfFalseBB = llvm::BasicBlock::Create(TheContext, "iffalse", func);
		llvm::BasicBlock* IfEndBB = llvm::BasicBlock::Create(TheContext, "ifend", func);

		descriptor* d1 = new descriptor;
		d1->block_ptr = IfStartBB;
		(symtbl.front())["ifstart"]  = d1;

		descriptor* d2 = new descriptor;
		d2->block_ptr = IfTrueBB;
		(symtbl.front())["iftrue"]  = d2;

		descriptor* d3 = new descriptor;
		d3->block_ptr = IfFalseBB;
		(symtbl.front())["iffalse"]  = d3;

		descriptor* d4 = new descriptor;
		d4->block_ptr = IfEndBB;
		(symtbl.front())["ifend"]  = d4;

		Builder.CreateBr(IfStartBB);
		Builder.SetInsertPoint(IfStartBB);
		llvm::Value* Cond = Condition->Codegen();   
		Builder.CreateCondBr(Cond, IfTrueBB, IfFalseBB);

		Builder.SetInsertPoint(IfTrueBB);
		If_Block->Codegen();
		Builder.CreateBr(IfEndBB);

		Builder.SetInsertPoint(IfFalseBB);
		if(Else_Block != NULL){
			Else_Block->Codegen();
		}
		Builder.CreateBr(IfEndBB);
		
		Builder.SetInsertPoint(IfEndBB);
		return NULL;
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
	llvm::Value *Codegen(){
		symbol_table syms;
		symtbl.push_front(syms);

		llvm::BasicBlock *CurBB = Builder.GetInsertBlock();
		llvm::Function *func = CurBB->getParent();
	
		llvm::BasicBlock* WhileStartBB = llvm::BasicBlock::Create(TheContext, "whilestart", func);
		llvm::BasicBlock* WhileTrueBB  = llvm::BasicBlock::Create(TheContext, "whiletrue",  func);
		llvm::BasicBlock* WhileEndBB   = llvm::BasicBlock::Create(TheContext, "whileend", func);     

		descriptor* d1 = new descriptor;
		d1->block_ptr = WhileStartBB;
		(symtbl.front())["loopstart"] = d1;

		descriptor* d2 = new descriptor;
		d2->block_ptr = WhileTrueBB;
		(symtbl.front())["looptrue"] = d2; 

		descriptor* d3 = new descriptor;
		d3->block_ptr = WhileEndBB;
		(symtbl.front())["loopend"] = d3;

		Builder.CreateBr(WhileStartBB);
		Builder.SetInsertPoint(WhileStartBB);
		llvm::Value* Cond = Condition->Codegen(); 
		Builder.CreateCondBr(Cond, WhileTrueBB, WhileEndBB);
		
		Builder.SetInsertPoint(WhileTrueBB);
		Block->Codegen();
		Builder.CreateBr(WhileStartBB);

		Builder.SetInsertPoint(WhileEndBB);
		symtbl.pop_front();
		return NULL;
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
	llvm::Value *Codegen(){
		symbol_table syms;
		symtbl.push_front(syms);

		llvm::BasicBlock *CurBB = Builder.GetInsertBlock();
		llvm::Function *func = CurBB->getParent();
		
		llvm::BasicBlock* ForStartBB = llvm::BasicBlock::Create(TheContext, "forstart", func);
		llvm::BasicBlock* ForTrueBB  = llvm::BasicBlock::Create(TheContext, "fortrue",  func);
		llvm::BasicBlock* ForPostBB  = llvm::BasicBlock::Create(TheContext, "forpost",  func);
		llvm::BasicBlock* ForEndBB   = llvm::BasicBlock::Create(TheContext, "forend",   func);     

		descriptor* d1 = new descriptor;
		d1->block_ptr = ForStartBB;
		(symtbl.front())["loopassign"]  = d1;

		descriptor* d2 = new descriptor;
		d2->block_ptr = ForTrueBB;
		(symtbl.front())["looptrue"]   = d2; 

		descriptor* d3 = new descriptor;
		d3->block_ptr = ForPostBB;
		(symtbl.front())["loopstart"] = d3;

		descriptor* d4 = new descriptor;
		d4->block_ptr = ForEndBB;
		(symtbl.front())["loopend"]    = d4;

		PreAssignList->Codegen();

		Builder.CreateBr(ForStartBB);
		Builder.SetInsertPoint(ForStartBB);
		llvm::Value* Cond = Condition->Codegen();
		Builder.CreateCondBr(Cond, ForTrueBB, ForEndBB);

		Builder.SetInsertPoint(ForTrueBB);
		Block->Codegen();
		Builder.CreateBr(ForPostBB);
	
		Builder.SetInsertPoint(ForPostBB); 
		LoopAssignList->Codegen();
		Builder.CreateBr(ForStartBB);

		Builder.SetInsertPoint(ForEndBB);
		symtbl.pop_front();
		return NULL;
	}
};

class ContinueAST : public decafAST
{  
public: 
	ContinueAST() {}
	string str()
	{
		return string("ContinueStmt");
	}
	llvm::Value *Codegen() 
	{
		llvm::BasicBlock *CurBB = Builder.GetInsertBlock();
		llvm::Function *func = CurBB->getParent();

		descriptor *d;
		d = access_symtbl("loopstart");
		llvm::BasicBlock* StartBB = d->block_ptr;
		if(StartBB != NULL)
		{
			Builder.CreateBr(StartBB);
			llvm::BasicBlock* idk = llvm::BasicBlock::Create(TheContext, "idk", func);
			Builder.SetInsertPoint(idk);
		}
		return NULL;
	}
};

class BreakAST : public decafAST
{  
public: 
	BreakAST() {}
	string str()
	{
		return string("BreakStmt");
	}
	llvm::Value *Codegen() 
	{
		llvm::BasicBlock *CurBB = Builder.GetInsertBlock();
		llvm::Function *func = CurBB->getParent();

		descriptor *d;
		d = access_symtbl("loopend");
		llvm::BasicBlock* EndBB = d->block_ptr;
		if(EndBB != NULL)
		{
			Builder.CreateBr(EndBB);
			llvm::BasicBlock* idk = llvm::BasicBlock::Create(TheContext, "idk", func);
			Builder.SetInsertPoint(idk);
		}
		return NULL;
	}
};

class ReturnAST : public decafAST {
	decafStmtList *Expr;
public:
	ReturnAST(decafStmtList *expr) : Expr(expr) {}
	string str() {
		return string("ReturnStmt") + "(" + getString(Expr) + ")";
	}
	llvm::Value *Codegen(){
		llvm::Value* val;
		llvm::BasicBlock *CurrBB = Builder.GetInsertBlock();
		llvm::Function *func = CurrBB->getParent();
		llvm::Type* returnTy = func->getReturnType();
		val = getZeroInit("IntType");
	
		if(Expr != NULL)
		{
			val = Expr->Codegen();
			Builder.CreateRet(val);
		}
		return val;
	}
};

llvm::Value* short_circuit_and(decafAST *LeftValue, decafAST *RightValue){
    llvm::Function *func = Builder.GetInsertBlock()->getParent();
    llvm::BasicBlock *and_right = llvm::BasicBlock::Create(TheContext, "andright",func);
    llvm::BasicBlock *and_end = llvm::BasicBlock::Create(TheContext, "andend",func);

    llvm::Value *left = LeftValue->Codegen();
    llvm::BasicBlock *CurBB = Builder.GetInsertBlock();
    Builder.CreateCondBr(left, and_right, and_end);

    Builder.SetInsertPoint(and_right);
    llvm::Value *right = RightValue->Codegen();
    llvm::Value *res = Builder.CreateAnd(left, right, "andtemp");
    llvm::BasicBlock *after = Builder.GetInsertBlock();
    Builder.CreateBr(and_end);

    Builder.SetInsertPoint(and_end);
    llvm::PHINode *val = Builder.CreatePHI(Builder.getInt1Ty(), 2, "phival");
    val->addIncoming(left, CurBB);
    val->addIncoming(res, after);

    return val;
}

llvm::Value* short_circuit_or(decafAST *LeftValue, decafAST *RightValue){
    llvm::Function *func = Builder.GetInsertBlock()->getParent();
    llvm::BasicBlock *or_right = llvm::BasicBlock::Create(TheContext, "orright",func);
    llvm::BasicBlock *or_end = llvm::BasicBlock::Create(TheContext, "orend",func);

    llvm::Value *left = LeftValue->Codegen();
    llvm::BasicBlock *CurBB = Builder.GetInsertBlock();
    Builder.CreateCondBr(left, or_end, or_right);

    Builder.SetInsertPoint(or_right);
    llvm::Value *right = RightValue->Codegen();
    llvm::Value *res = Builder.CreateOr(left, right, "ortemp");
    llvm::BasicBlock *after = Builder.GetInsertBlock();
    Builder.CreateBr(or_end);

    Builder.SetInsertPoint(or_end);
    llvm::PHINode *val = Builder.CreatePHI(Builder.getInt1Ty(), 2, "phival");
    val->addIncoming(left, CurBB);
    val->addIncoming(res, after);

    return val;
}

class BinaryExpr : public decafAST {
	string BinaryOperator;
	decafAST *LeftValue;
	decafAST *RightValue;
public:
	BinaryExpr(string op, decafAST *l, decafAST *r) : BinaryOperator(op), LeftValue(l), RightValue(r) {}
	string str() {
		return string("BinaryExpr") + "(" + BinaryOperator + "," + getString(LeftValue) + "," + getString(RightValue) + ")";
	}
	llvm::Value *Codegen(){
		llvm::Value* val;
		if( (BinaryOperator == "And") ){
			return short_circuit_and(LeftValue,RightValue);
		}
		else if( (BinaryOperator == "Or") ){
			return short_circuit_or(LeftValue,RightValue);
		}
		else{
			llvm::Value* LValue = LeftValue->Codegen();
			llvm::Value* RValue = RightValue->Codegen();
		
		if(BinaryOperator == "Plus")       { val = Builder.CreateAdd(LValue,RValue,"addtmp");  }
		if(BinaryOperator == "Minus")      { val = Builder.CreateSub(LValue,RValue,"subtmp");  }
		if(BinaryOperator == "Mult")       { val = Builder.CreateMul(LValue,RValue,"multmp");  }
		if(BinaryOperator == "Div")        { val = Builder.CreateSDiv(LValue,RValue,"divtmp"); }
		if(BinaryOperator == "Leftshift")  { val = Builder.CreateShl(LValue, RValue,"lstmp");  }
		if(BinaryOperator == "Rightshift") { val = Builder.CreateLShr(LValue, RValue,"rstmp");  }
		if(BinaryOperator == "Mod")        { val = Builder.CreateSRem(LValue, RValue,"remtmp");  } 
		if(BinaryOperator == "Lt")         { val = Builder.CreateICmpSLT(LValue, RValue,"lttmp");  }
		if(BinaryOperator == "Gt")         { val = Builder.CreateICmpSGT(LValue, RValue,"gttmp");  }
		if(BinaryOperator == "Leq")        { val = Builder.CreateICmpSLE(LValue, RValue,"leqtmp");  }
		if(BinaryOperator == "Geq")        { val = Builder.CreateICmpSGE(LValue, RValue,"geqtmp");  }
//		if(BinaryOperator == "And")        { val = Builder.CreateAnd(LValue, RValue,"andtmp");  }
//		if(BinaryOperator == "Or")         { val = Builder.CreateOr(LValue, RValue,"ortmp");  }
		if(BinaryOperator == "Eq")         { val = Builder.CreateICmpEQ(LValue, RValue,"eqtmp");  }
		if(BinaryOperator == "Neq")        { val = Builder.CreateICmpNE(LValue, RValue,"neqtmp"); }
		return val;
		}
		return val;
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
	llvm::Value *Codegen(){
		llvm::Value* val;
		llvm::Value* RValue = Expr->Codegen();
		if(UnaryOperator == "Not")        { val = Builder.CreateNot(RValue, "nottmp");  } 
		if(UnaryOperator == "UnaryMinus") { val = Builder.CreateNeg(RValue, "negtmp");  }
		return val;
	}
};

string removeChar(string s, char c){
	string str = "";
	for(int i = 0; i < s.size(); i++){
		if(s[i] != c){
			str = str + s[i];
		}
		else{
			if(s[i+1] == 'a') {
				str = str + '\a';
				i++;
			}
			else if(s[i+1] == 'b') {
				str = str + '\b';
				i++;
			}
			else if(s[i+1] == 't') {
				str = str + '\t';
				i++;
			}
			else if(s[i+1] == 'n') {
				str = str + '\n';
				i++;
			}
			else if(s[i+1] == 'v') {
				str = str + '\v';
				i++;
			}
			else if(s[i+1] == 'f') {
				str = str + '\f';
				i++;
			}
			else if(s[i+1] == 'r') {
				str = str + '\r';
				i++;
			}
			else if(s[i+1] == '\\') {
				str = str + '\\';
				i++;
			}
			else if(s[i+1] == '\'') {
				str = str + '\'';
				i++;
			}
			else if(s[i+1] == '\"') {
				str = str + '\"';
				i++;
			}
		}
	}
	return str;
}

class StringConstantAST : public decafAST {
	string value;
public:
	StringConstantAST(string v) : value(v) {}
	string str() {
		return string("StringConstant") + "(" + value + ")";
	}
	llvm::Value *Codegen(){
		llvm::GlobalVariable *GS = Builder.CreateGlobalString(removeChar(value.substr(1, value.size() - 2), '\\'), "globalstring");
		return Builder.CreateConstGEP2_32(GS->getValueType(), GS, 0, 0, "cast");
	}
};
