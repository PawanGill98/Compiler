
#ifndef _DECAF_DEFS
#define _DECAF_DEFS

#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Type.h"
#include "llvm/IR/Verifier.h"
#include "llvm/IR/IRBuilder.h"
#include <cstdio> 
#include <cstdlib>
#include <cstring> 
#include <string>
#include <stdexcept>
#include <vector>

extern int lineno;
extern int tokenpos;

using namespace std;

extern "C"
{
	extern int yyerror(const char *);
	int yyparse(void);
	int yylex(void);  
	int yywrap(void);
}

typedef struct array {
    std::string* size;
    std::string* type;
    } arr;

typedef struct descriptor 
{ 
  int lineno;
  string type;
  llvm::AllocaInst* alloca_ptr;
  llvm::Function*     func_ptr;
  vector<llvm::Type*> arg_types;
  vector<string>      arg_names;
  llvm::GlobalVariable *global_ptr;
  llvm::BasicBlock *block_ptr;
}descriptor; 

typedef map<string, descriptor*> symbol_table;

typedef list<symbol_table> symbol_table_list;

extern int lineno;

extern int tokenpos;

extern symbol_table_list symtbl;

extern descriptor* access_symtbl(string id);

extern void print_descriptor(string id);

#endif

