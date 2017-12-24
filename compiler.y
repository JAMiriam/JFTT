%{
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#include <stdarg.h>
#include <iostream>
#include <fstream>
#include <string>
#include <map>
#include <vector>
#include <algorithm>
using namespace std;

typedef struct {
	string name;
	long long int mem;
	long long int local;
  	long long int tableSize;
  	int initialized;
    string type; //NUM, IDE, ARR
} Identifier;

typedef struct {
    long long int placeInStack;
    long long int depth;
} Jump;

map<string, Identifier> identifierStack;
vector<string> codeStack;
vector<Jump> jumpStack;
vector<Identifier> forStack;
/*vector<long long int> initializedMem;*/

int yylex();
extern int yylineno;
int yyerror(const string str);

void pushCommand(string str);
void pushCommandOneArg(string str, long long int num);
void createIdentifier(Identifier *s, string name, long long int isLocal,
    long long int isArray, string type);
void insertIdentifier(string key, Identifier i);
void removeIdentifier(string key);
void createJump(Jump *j, long long int stack, long long int depth);
void registerToMem(long long int mem);
void setRegister(string number);
void zeroRegister();
void memToRegister(long long int mem);
void registerToMem();
void add(Identifier a, Identifier b);
void addTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex);
void sub(Identifier a, Identifier b, int isINC);
void subTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex, int isINC);
void addInt(long long int command, long long int val);
string decToBin(long long int dec);

long long int memCounter;
/*long long int registerValue;*/
long long int depth;
int assignFlag;
int writeFlag;
Identifier assignTarget;
string tabAssignTargetIndex = "-1";
string expressionArguments[2] = {"-1", "-1"};
string argumentsTabIndex[2] = {"-1", "-1"};

%}

%define parse.error verbose
%define parse.lac full
%union {
    char* str;
    long long int num;
}
%token <str> NUM
%token <str> VAR BEG END IF THEN ELSE ENDIF
%token <str> WHILE DO ENDWHILE FOR FROM ENDFOR
%token <str> WRITE READ IDE SEM TO DOWNTO
%token <str> LB RB ASG EQ LT GT LE GE NE ADD SUB MUL DIV MOD

%type <str> value
%type <str> identifier


%%
program:
    VAR vdeclarations BEG commands END {
        pushCommand("HALT");
    }
;

vdeclarations:
    vdeclarations IDE {
        if(identifierStack.find($2)!=identifierStack.end()) {
            cout << "Błąd [okolice linii " << yylineno \
            << "]: Kolejna deklaracja zmiennej " << $<str>2 << "." << endl;
            exit(1);
        }
        else {
            Identifier s;
            createIdentifier(&s, $2, 0, 0, "IDE");
            insertIdentifier($2, s);
        }
    }
|   vdeclarations IDE LB NUM RB {
        if(identifierStack.find($2)!=identifierStack.end()) {
            cout << "Błąd [okolice linii " << yylineno \
            << "]: Kolejna deklaracja zmiennej " << $<str>2 << "." << endl;
            exit(1);
        }
        else if (atoll($4) <= 0) {
            cout << "Błąd [okolice linii " << yylineno \
            << "]: Deklarowanie tablicy " << $<str>2 << " o rozmiarze zero." << endl;
            exit(1);
        }
        else {
            long long int size = atoll($4);
            Identifier s;
            createIdentifier(&s, $2, 0, size, "ARR");
            insertIdentifier($2, s);
            memCounter += size;
            setRegister(to_string(s.mem+1));
            registerToMem(s.mem);
        }
    }
|
;

commands:
    commands command
|   command
;

command:
    identifier ASG {
        assignFlag = 0;
    } expression SEM {
        /*if(depth > 0 && assignTarget.initialized == 0){
            cout << "Błąd <linia " << yylineno << ">: Warunkowa inicjalizaja zmiennej " \
            << assignTarget.name << "!" << endl;
      		exit(1);
        }*/
        if(assignTarget.type == "ARR") {
            Identifier index = identifierStack.at(tabAssignTargetIndex);
            if(index.type == "NUM") {
                long long int tabElMem = assignTarget.mem + stoll(index.name) + 1;
                registerToMem(tabElMem);
                removeIdentifier(index.name);
            }
            else {
                registerToMem(0);
                memToRegister(assignTarget.mem);
                pushCommandOneArg("ADD", index.mem);
                registerToMem(2);
                memToRegister(0);
                pushCommandOneArg("STOREI", 2);
            }
        }
        else if(assignTarget.local == 0) {
            registerToMem(assignTarget.mem);
        }
      	else {
            cout << "Błąd [okolice linii " << yylineno << \
            "]: Próba modyfikacji iteratora pętli." << endl;
      		exit(1);
      	}
        identifierStack.at(assignTarget.name).initialized = 1;
        /*if(initializedMem.empty() ||
            find(initializedMem.begin(), initializedMem.end(), assignTarget.name) == initializedMem.end())) {
            initializedMem.push_back(assignTarget.mem);
        }*/
      	assignFlag = 1;
    }
|   IF {assignFlag = 0;
        depth++;
    } condition {
        assignFlag = 1;
    } THEN commands ifbody

|   WHILE {
        assignFlag = 0;
        depth++;
        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
    } condition {
        assignFlag = 1;
    } DO commands ENDWHILE {
        long long int stack;
        long long int jumpCount = jumpStack.size()-1;
        if(jumpCount > 2 && jumpStack.at(jumpCount-2).depth == depth) {
            stack = jumpStack.at(jumpCount-2).placeInStack;
            pushCommandOneArg("JUMP", stack);
            addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
            addInt(jumpStack.at(jumpCount-1).placeInStack, codeStack.size());
            jumpStack.pop_back();
        }
        else {
            stack = jumpStack.at(jumpCount-1).placeInStack;
            pushCommandOneArg("JUMP", stack);
            addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
        }
        jumpStack.pop_back();
        jumpStack.pop_back();

        /*registerValue = -1;*/
        depth--;
        assignFlag = 1;
    }
|   FOR IDE {
        if(identifierStack.find($2)!=identifierStack.end()) {
            cout << "Błąd [okolice linii " << yylineno \
            << "]: Kolejna deklaracja zmiennej " << $<str>2 << "." << endl;
            exit(1);
        }
        else {
            Identifier s;
            createIdentifier(&s, $2, 1, 0, "IDE");
            s.initialized = 1;
            insertIdentifier($2, s);
        }
        assignFlag = 0;
        assignTarget = identifierStack.at($2);
        depth++;
    } FROM value forbody
|   READ identifier {
        assignFlag = 1;
    } SEM {
        /*registerValue = -1;*/
        if(assignTarget.type == "ARR") {
            Identifier index = identifierStack.at(tabAssignTargetIndex);
            if(index.type == "NUM") {
                pushCommand("GET");
                long long int tabElMem = assignTarget.mem + stoll(index.name) + 1;
                registerToMem(tabElMem);
                removeIdentifier(index.name);
            }
            else {
                memToRegister(assignTarget.mem);
                pushCommandOneArg("ADD", index.mem);
                registerToMem(2);
                pushCommand("GET");
                pushCommandOneArg("STOREI", 2);
            }
        }
        else if(assignTarget.local == 0) {
            pushCommand("GET");
            registerToMem(assignTarget.mem);
        }
        else {
            cout << "Błąd [okolice linii " << yylineno << \
            "]: Próba modyfikacji iteratora pętli." << endl;
            exit(1);
        }
        identifierStack.at(assignTarget.name).initialized = 1;
        assignFlag = 1;
    }
|   WRITE {
        assignFlag = 0;
        writeFlag = 1;
    } value SEM {
        Identifier ide = identifierStack.at(expressionArguments[0]);

        if(ide.type == "NUM") {
            setRegister(ide.name);
            removeIdentifier(ide.name);
        }
        else if (ide.type == "IDE") {
            memToRegister(ide.mem);
        }
        else {
            Identifier index = identifierStack.at(argumentsTabIndex[0]);
            if(index.type == "NUM") {
                long long int tabElMem = ide.mem + stoll(index.name) + 1;
                memToRegister(tabElMem);
                removeIdentifier(index.name);
            }
            else {
                memToRegister(ide.mem);
                pushCommandOneArg("ADD", index.mem);
                pushCommandOneArg("STORE", 0);
                pushCommandOneArg("LOADI", 0);
            }
        }
        pushCommand("PUT");
        assignFlag = 1;
        writeFlag = 0;
        expressionArguments[0] = "-1";
        argumentsTabIndex[0] = "-1";
    }
;

ifbody:
    ELSE {
        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JUMP");
        long long int jumpCount = jumpStack.size()-2;
        Jump jump = jumpStack.at(jumpCount);
        addInt(jump.placeInStack, codeStack.size());

        jumpCount--;
        if(jumpCount >= 0 && jumpStack.at(jumpCount).depth == depth) {
            addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
        }
        /*registerValue = -1;*/
        assignFlag = 1;
    } commands ENDIF {
        addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size());
        jumpStack.pop_back();
        jumpStack.pop_back();
        if(jumpStack.size() >= 1 && jumpStack.at(jumpStack.size()-1).depth == depth) {
            jumpStack.pop_back();
        }
        depth--;
        assignFlag = 1;
    }
|   ENDIF {
        long long int jumpCount = jumpStack.size()-1;
        addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
        jumpCount--;
        if(jumpCount >= 0 && jumpStack.at(jumpCount).depth == depth) {
            addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
            jumpStack.pop_back();
        }
        jumpStack.pop_back();
        /*registerValue = -1;*/
        depth--;
        assignFlag = 1;
    }
;

forbody:
    DOWNTO value {} DO commands ENDFOR { depth--;}
|   TO value DO {
        //TODO have to assign iterator and create counter
        /*Identifier s;
        string name = "C" + to_string(depth);
        createIdentifier(&s, name, 1, 0, "IDE");
        insertIdentifier(name, s);*/

        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM") {
            setRegister(a.name);
            /*removeIdentifier(a.name);*/
        }
        else if(a.type == "IDE") {
            memToRegister(a.mem);
        }
        else {
            Identifier index = identifierStack.at(argumentsTabIndex[0]);
            if(index.type == "NUM") {
                long long int tabElMem = a.mem + stoll(index.name) + 1;
                memToRegister(tabElMem);
                /*removeIdentifier(index.name);*/
            }
            else {
                memToRegister(a.mem);
                pushCommandOneArg("ADD", index.mem);
                pushCommandOneArg("STORE", 0);
                pushCommandOneArg("LOADI", 0);
            }
        }
        registerToMem(assignTarget.mem);

        if(a.type != "ARR" && b.type != "ARR")
            sub(b, a, 1);
        else {
            Identifier aI, bI;
            if(identifierStack.count(argumentsTabIndex[0]) > 0)
                aI = identifierStack.at(argumentsTabIndex[0]);
            if(identifierStack.count(argumentsTabIndex[1]) > 0)
                bI = identifierStack.at(argumentsTabIndex[1]);
            subTab(b, a, bI, aI, 1);
            argumentsTabIndex[0] = "-1";
            argumentsTabIndex[1] = "-1";
        }
        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";

        Identifier s;
        string name = "C" + to_string(depth);
        createIdentifier(&s, name, 1, 0, "IDE");
        insertIdentifier(name, s);

        registerToMem(identifierStack.at(name).mem);
        forStack.push_back(assignTarget);

        pushCommandOneArg("JZERO", codeStack.size()+2);
        //TODO jak są zmienne to trzeba warunek końca
        memToRegister(identifierStack.at(name).mem);
        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JZERO");
        pushCommand("DEC");
        registerToMem(identifierStack.at(name).mem);
        assignFlag = 1;
    } commands ENDFOR {
        Identifier iterator = forStack.at(forStack.size()-1);
        //TODO increment iterator and think if everything with it is ok
        memToRegister(iterator.mem);
        pushCommand("INC");
        registerToMem(iterator.mem);

        long long int jumpCount = jumpStack.size()-1;
        long long int stack = jumpStack.at(jumpCount).placeInStack-1;
        pushCommandOneArg("JUMP", stack);
        addInt(jumpStack.at(jumpCount).placeInStack, codeStack.size());
        jumpStack.pop_back();

        string name = "C" + to_string(depth);
        removeIdentifier(name);
        removeIdentifier(iterator.name);
        forStack.pop_back();
        depth--;
        assignFlag = 1;
    }
;

expression:
    value {
        Identifier ide = identifierStack.at(expressionArguments[0]);
        if(ide.type == "NUM") {
            setRegister(ide.name);
            removeIdentifier(ide.name);
        }
        else if(ide.type == "IDE") {
            memToRegister(ide.mem);
        }
        else {
            Identifier index = identifierStack.at(argumentsTabIndex[0]);
            if(index.type == "NUM") {
                long long int tabElMem = ide.mem + stoll(index.name) + 1;
                memToRegister(tabElMem);
                removeIdentifier(index.name);
            }
            else {
                memToRegister(ide.mem);
                pushCommandOneArg("ADD", index.mem);
                pushCommandOneArg("STORE", 0);
                pushCommandOneArg("LOADI", 0);
            }
        }
      	if (!writeFlag) {
            expressionArguments[0] = "-1";
            argumentsTabIndex[0] = "-1";
        }
    }
|   value ADD value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);
        if(a.type != "ARR" && b.type != "ARR")
            add(a, b);
        else {
            Identifier aI, bI;
            if(identifierStack.count(argumentsTabIndex[0]) > 0)
                aI = identifierStack.at(argumentsTabIndex[0]);
            if(identifierStack.count(argumentsTabIndex[1]) > 0)
                bI = identifierStack.at(argumentsTabIndex[1]);
            addTab(a, b, aI, bI);
            argumentsTabIndex[0] = "-1";
            argumentsTabIndex[1] = "-1";
        }
        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
|   value SUB value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);
        if(a.type != "ARR" && b.type != "ARR")
            sub(a, b, 0);
        else {
            Identifier aI, bI;
            if(identifierStack.count(argumentsTabIndex[0]) > 0)
                aI = identifierStack.at(argumentsTabIndex[0]);
            if(identifierStack.count(argumentsTabIndex[1]) > 0)
                bI = identifierStack.at(argumentsTabIndex[1]);
            subTab(a, b, aI, bI, 0);
            argumentsTabIndex[0] = "-1";
            argumentsTabIndex[1] = "-1";
        }
        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
|   value {} MUL value {}
|   value {} DIV value {}
|   value {} MOD value {}
;

condition:
    value EQ value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(a.name) == stoll(b.name))
                setRegister("1");
            else
                setRegister("0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
            Jump jum;
            createJump(&jum, codeStack.size(), depth);
            jumpStack.push_back(jum);
            pushCommand("JZERO");
        }
        else {
            Identifier aI, bI;
            if(identifierStack.count(argumentsTabIndex[0]) > 0)
                aI = identifierStack.at(argumentsTabIndex[0]);
            if(identifierStack.count(argumentsTabIndex[1]) > 0)
                bI = identifierStack.at(argumentsTabIndex[1]);

            if(a.type != "ARR" && b.type != "ARR")
                sub(b, a, 0);
            else
                subTab(b, a, bI, aI, 0);

            pushCommandOneArg("JZERO", codeStack.size()+2);
            Jump j;
            createJump(&j, codeStack.size(), depth);
            jumpStack.push_back(j);
            pushCommand("JUMP");

            if(a.type != "ARR" && b.type != "ARR")
                sub(a, b, 0);
            else
                subTab(a, b, aI, bI, 0);

            pushCommandOneArg("JZERO", codeStack.size()+2);
            Jump jj;
            createJump(&jj, codeStack.size(), depth);
            jumpStack.push_back(jj);
            pushCommand("JUMP");
        }

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
        argumentsTabIndex[0] = "-1";
        argumentsTabIndex[1] = "-1";
    }
|   value NE value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(a.name) != stoll(b.name))
                setRegister("1");
            else
                setRegister("0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
            Jump jum;
            createJump(&jum, codeStack.size(), depth);
            jumpStack.push_back(jum);
            pushCommand("JZERO");
        }
        else {
            Identifier aI, bI;
            if(identifierStack.count(argumentsTabIndex[0]) > 0)
                aI = identifierStack.at(argumentsTabIndex[0]);
            if(identifierStack.count(argumentsTabIndex[1]) > 0)
                bI = identifierStack.at(argumentsTabIndex[1]);

            if(a.type != "ARR" && b.type != "ARR")
                sub(b, a, 0);
            else
                subTab(b, a, bI, aI, 0);

            pushCommandOneArg("JZERO", codeStack.size()+2);
            Jump j;
            createJump(&j, codeStack.size(), depth);
            jumpStack.push_back(j);
            pushCommand("JUMP");

            if(a.type != "ARR" && b.type != "ARR")
                sub(a, b, 0);
            else
                subTab(a, b, aI, bI, 0);

            addInt(jumpStack.at(jumpStack.size()-1).placeInStack, codeStack.size()+1);
            jumpStack.pop_back();

            Jump jj;
            createJump(&jj, codeStack.size(), depth);
            jumpStack.push_back(jj);
            pushCommand("JZERO");
        }

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
        argumentsTabIndex[0] = "-1";
        argumentsTabIndex[1] = "-1";
    }
|   value LT value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(a.name) < stoll(b.name))
                setRegister("1");
            else
                setRegister("0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else {
            if(a.type != "ARR" && b.type != "ARR")
                sub(b, a, 0);
            else {
                Identifier aI, bI;
                if(identifierStack.count(argumentsTabIndex[0]) > 0)
                    aI = identifierStack.at(argumentsTabIndex[0]);
                if(identifierStack.count(argumentsTabIndex[1]) > 0)
                    bI = identifierStack.at(argumentsTabIndex[1]);
                subTab(b, a, bI, aI, 0);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JZERO");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
|   value GT value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(b.name) < stoll(a.name))
                setRegister("1");
            else
                setRegister("0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else {
            if(a.type != "ARR" && b.type != "ARR")
                sub(a, b, 0);
            else {
                Identifier aI, bI;
                if(identifierStack.count(argumentsTabIndex[0]) > 0)
                    aI = identifierStack.at(argumentsTabIndex[0]);
                if(identifierStack.count(argumentsTabIndex[1]) > 0)
                    bI = identifierStack.at(argumentsTabIndex[1]);
                subTab(a, b, aI, bI, 0);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);;
        pushCommand("JZERO");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
|   value LE value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(a.name) <= stoll(b.name))
                setRegister("1");
            else
                setRegister("0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else {
            if(a.type != "ARR" && b.type != "ARR")
                sub(b, a, 1);
            else {
                Identifier aI, bI;
                if(identifierStack.count(argumentsTabIndex[0]) > 0)
                    aI = identifierStack.at(argumentsTabIndex[0]);
                if(identifierStack.count(argumentsTabIndex[1]) > 0)
                    bI = identifierStack.at(argumentsTabIndex[1]);
                subTab(b, a, bI, aI, 1);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JZERO");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
    }
|   value GE value {
        Identifier a = identifierStack.at(expressionArguments[0]);
        Identifier b = identifierStack.at(expressionArguments[1]);

        if(a.type == "NUM" && b.type == "NUM") {
            if(stoll(a.name) >= stoll(b.name))
                setRegister("1");
            else
                setRegister("0");
            removeIdentifier(a.name);
            removeIdentifier(b.name);
        }
        else {
            if(a.type != "ARR" && b.type != "ARR")
                sub(a, b, 1);
            else {
                Identifier aI, bI;
                if(identifierStack.count(argumentsTabIndex[0]) > 0)
                    aI = identifierStack.at(argumentsTabIndex[0]);
                if(identifierStack.count(argumentsTabIndex[1]) > 0)
                    bI = identifierStack.at(argumentsTabIndex[1]);
                subTab(a, b, aI, bI, 1);
                argumentsTabIndex[0] = "-1";
                argumentsTabIndex[1] = "-1";
            }
        }

        Jump j;
        createJump(&j, codeStack.size(), depth);
        jumpStack.push_back(j);
        pushCommand("JZERO");

        expressionArguments[0] = "-1";
        expressionArguments[1] = "-1";
        argumentsTabIndex[0] = "-1";
        argumentsTabIndex[1] = "-1";
    }
;

value:
    NUM {
        if(assignFlag){
            cout << "Błąd [okolice linii " << yylineno << \
            "]: Próba przypisania do stałej." << endl;
           	exit(1);
      	}
        Identifier s;
      	createIdentifier(&s, $1, 0, 0, "NUM");
        insertIdentifier($1, s);
      	if (expressionArguments[0] == "-1"){
      		expressionArguments[0] = $1;
      	}
      	else{
      		expressionArguments[1] = $1;
      	}
    }
|   identifier
;

identifier:
    IDE {
        if(identifierStack.find($1) == identifierStack.end()) {
            cout << "Błąd [okolice linii " << yylineno << \
            "]: Zmienna " << $1 << " nie została zadeklarowana." << endl;
            exit(1);
        }
        if(identifierStack.at($1).tableSize == 0) {
            if(!assignFlag){
                if(identifierStack.at($1).initialized == 0) {
                    cout << "Błąd [okolice linii " << yylineno << \
                    "]: Próba użycia niezainicjalizowanej zmiennej " << $1 << "." << endl;
                    exit(1);
                }
                if (expressionArguments[0] == "-1"){
                    expressionArguments[0] = $1;
                }
                else{
                    expressionArguments[1] = $1;
                }

            }
            else {
                assignTarget = identifierStack.at($1);
            }
        }
        else {
          cout << "Błąd [okolice linii " << yylineno << \
          "]: Brak odwołania do elementu tablicy " << $1 << "." << endl;
          exit(1);
        }
    }
|   IDE LB IDE RB {
        if(identifierStack.find($1) == identifierStack.end()) {
            cout << "Błąd [okolice linii " << yylineno << \
            "]: Zmienna " << $1 << " nie została zadeklarowana." << endl;
            exit(1);
        }
        if(identifierStack.find($3) == identifierStack.end()) {
            cout << "Błąd [okolice linii " << yylineno << \
            "]: Zmienna " << $1 << " nie została zadeklarowana." << endl;
            exit(1);
        }

        if(identifierStack.at($1).tableSize == 0) {
            cout << "Błąd [okolice linii " << yylineno << \
            "]: Zmienna " << $1 << " nie jest tablicą." << endl;
            exit(1);
        }
        else {
            if(identifierStack.at($3).initialized == 0) {
                cout << "Błąd [okolice linii " << yylineno << \
                "]: Próba użycia niezainicjalizowanej zmiennej " << $3 << "." << endl;
                exit(1);
            }

            if(!assignFlag){
                //TODO czy wywalać błąd niezainicjalizowanej
                //zmiennej dla elementu tablicy
                if (expressionArguments[0] == "-1"){
                    expressionArguments[0] = $1;
                    argumentsTabIndex[0] = $3;
                }
                else{
                    expressionArguments[1] = $1;
                    argumentsTabIndex[1] = $3;
                }

            }
            else {
                assignTarget = identifierStack.at($1);
                tabAssignTargetIndex = $3;
            }
        }
    }
|   IDE LB NUM RB {
        if(identifierStack.find($1) == identifierStack.end()) {
            cout << "Błąd [okolice linii " << yylineno << \
            "]: Zmienna " << $1 << " nie została zadeklarowana." << endl;
            exit(1);
        }

        if(identifierStack.at($1).tableSize == 0) {
            cout << "Błąd [okolice linii " << yylineno << \
            "]: Zmienna " << $1 << " nie jest tablicą." << endl;
            exit(1);
        }
        else {
            Identifier s;
            createIdentifier(&s, $3, 0, 0, "NUM");
            insertIdentifier($3, s);

            if(!assignFlag){
                //TODO czy wywalać błąd niezainicjalizowanej
                //zmiennej dla elementu tablicy
                if (expressionArguments[0] == "-1"){
                    expressionArguments[0] = $1;
                    argumentsTabIndex[0] = $3;
                }
                else{
                    expressionArguments[1] = $1;
                    argumentsTabIndex[1] = $3;
                }

            }
            else {
                assignTarget = identifierStack.at($1);
                tabAssignTargetIndex = $3;
            }
        }
    }
;

%%

void createIdentifier(Identifier *s, string name, long long int isLocal,
    long long int isArray, string type){
    s->name = name;
    s->mem = memCounter;
    s->type = type;
    s->initialized = 0;
    if(isLocal){
    	s->local = 1;
    }
    else{
    	s->local = 0;
    }
    if(isArray){
      s->tableSize = isArray;
    }
    else{
      s->tableSize = 0;
    }
}

void createJump(Jump *j, long long int stack, long long int depth) {
    j->placeInStack = stack;
    j->depth = depth;
}

void add(Identifier a, Identifier b) {
    if(a.type == "NUM" && b.type == "NUM") {
        long long int val = stoll(a.name) + stoll(b.name);
        setRegister(to_string(val));
        removeIdentifier(a.name);
        removeIdentifier(b.name);
    }
    else if(a.type == "NUM" && b.type == "IDE") {
        setRegister(a.name);
        pushCommandOneArg("ADD", b.mem);
        removeIdentifier(a.name);
    }
    else if(a.type == "IDE" && b.type == "NUM") {
        setRegister(b.name);
        pushCommandOneArg("ADD", a.mem);
        removeIdentifier(b.name);
    }
    else if(a.type == "IDE" && b.type == "IDE") {
        memToRegister(a.mem);
        pushCommandOneArg("ADD", b.mem);
    }
}

void addTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex) {
    if(a.type == "NUM" && b.type == "ARR") {
        if(bIndex.type == "NUM") {
            long long int addr = b.mem + stoll(bIndex.name) + 1;
            setRegister(a.name);
            pushCommandOneArg("ADD", addr);
            removeIdentifier(a.name);
            removeIdentifier(bIndex.name);
        }
        else if(bIndex.type == "IDE") {
            memToRegister(b.mem);
            pushCommandOneArg("ADD", bIndex.mem);
            registerToMem(1);
            setRegister(a.name);
            pushCommandOneArg("ADDI", 1);
            removeIdentifier(a.name);
        }
    }
    else if(a.type == "ARR" && b.type == "NUM") {
        if(aIndex.type == "NUM") {
            long long int addr = a.mem + stoll(aIndex.name) + 1;
            setRegister(b.name);
            pushCommandOneArg("ADD", addr);
            removeIdentifier(b.name);
            removeIdentifier(aIndex.name);
        }
        else if(aIndex.type == "IDE") {
            memToRegister(a.mem);
            pushCommandOneArg("ADD", aIndex.mem);
            registerToMem(1);
            setRegister(b.name);
            pushCommandOneArg("ADDI", 1);
            removeIdentifier(b.name);
        }
    }
    else if(a.type == "IDE" && b.type == "ARR") {
        if(bIndex.type == "NUM") {
            long long int addr = b.mem + stoll(bIndex.name) + 1;
            memToRegister(a.mem);
            pushCommandOneArg("ADD", addr);
            removeIdentifier(bIndex.name);
        }
        else if(bIndex.type == "IDE") {
            memToRegister(b.mem);
            pushCommandOneArg("ADD", bIndex.mem);
            registerToMem(1);
            memToRegister(a.mem);
            pushCommandOneArg("ADDI", 1);
        }
    }
    else if(a.type == "ARR" && b.type == "IDE") {
        if(aIndex.type == "NUM") {
            long long int addr = a.mem + stoll(aIndex.name) + 1;
            memToRegister(b.mem);
            pushCommandOneArg("ADD", addr);
            removeIdentifier(aIndex.name);
        }
        else if(aIndex.type == "IDE") {
            memToRegister(a.mem);
            pushCommandOneArg("ADD", aIndex.mem);
            registerToMem(1);
            memToRegister(b.mem);
            pushCommandOneArg("ADDI", 1);
        }
    }
    else if(a.type == "ARR" && b.type == "ARR") {
        if(aIndex.type == "NUM" && bIndex.type == "NUM") {
            long long int addrA = a.mem + stoll(aIndex.name) + 1;
            long long int addrB = b.mem + stoll(bIndex.name) + 1;
            memToRegister(addrA);
            pushCommandOneArg("ADD", addrB);
        }
        else if(aIndex.type == "NUM" && bIndex.type == "IDE") {
            long long int addrA = a.mem + stoll(aIndex.name) + 1;
            memToRegister(b.mem);
            pushCommandOneArg("ADD", bIndex.mem);
            registerToMem(1);
            memToRegister(addrA);
            pushCommandOneArg("ADDI", 1);
        }
        else if(aIndex.type == "IDE" && bIndex.type == "NUM") {
            long long int addrB = b.mem + stoll(bIndex.name) + 1;
            memToRegister(a.mem);
            pushCommandOneArg("ADD", aIndex.mem);
            registerToMem(1);
            memToRegister(addrB);
            pushCommandOneArg("ADDI", 1);
        }
        else if(aIndex.type == "IDE" && bIndex.type == "IDE") {
            memToRegister(a.mem);
            pushCommandOneArg("ADD", aIndex.mem);
            registerToMem(1);
            memToRegister(b.mem);
            pushCommandOneArg("ADD", bIndex.mem);
            registerToMem(0);
            pushCommandOneArg("LOADI", 1);
            pushCommandOneArg("ADDI", 0);
        }
    }
}

void sub(Identifier a, Identifier b, int isINC) {
    if(a.type == "NUM" && b.type == "NUM") {
        long long int val = max(stoll(a.name) + isINC - stoll(b.name), (long long int) 0);
        setRegister(to_string(val));
        removeIdentifier(a.name);
        removeIdentifier(b.name);
    }
    else if(a.type == "NUM" && b.type == "IDE") {
        setRegister(to_string(stoll(a.name) + isINC));
        pushCommandOneArg("SUB", b.mem);
        removeIdentifier(a.name);
    }
    else if(a.type == "IDE" && b.type == "NUM") {
        setRegister(b.name);
        registerToMem(3);
        memToRegister(a.mem);
        if(isINC)
            pushCommand("INC");
        pushCommandOneArg("SUB", 3);
        removeIdentifier(b.name);
    }
    else if(a.type == "IDE" && b.type == "IDE") {
        memToRegister(a.mem);
        if(isINC)
            pushCommand("INC");
        pushCommandOneArg("SUB", b.mem);
    }
}

void subTab(Identifier a, Identifier b, Identifier aIndex, Identifier bIndex, int isINC) {
    if(a.type == "NUM" && b.type == "ARR") {
        if(bIndex.type == "NUM") {
            long long int addr = b.mem + stoll(bIndex.name) + 1;
            setRegister(to_string(stoll(a.name) + isINC));
            pushCommandOneArg("SUB", addr);
            removeIdentifier(a.name);
            removeIdentifier(bIndex.name);
        }
        else if(bIndex.type == "IDE") {
            memToRegister(b.mem);
            pushCommandOneArg("ADD", bIndex.mem);
            registerToMem(1);
            setRegister(to_string(stoll(a.name) + isINC));
            pushCommandOneArg("SUBI", 1);
            removeIdentifier(a.name);
        }
    }
    else if(a.type == "ARR" && b.type == "NUM") {
        if(aIndex.type == "NUM") {
            long long int addr = a.mem + stoll(aIndex.name) + 1;
            setRegister(b.name);
            registerToMem(3);
            memToRegister(addr);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUB", 3);
            removeIdentifier(b.name);
            removeIdentifier(aIndex.name);
        }
        else if(aIndex.type == "IDE") {
            setRegister(b.name);
            registerToMem(3);
            memToRegister(a.mem);
            pushCommandOneArg("ADD", aIndex.mem);
            registerToMem(1);
            pushCommandOneArg("LOADI", 1);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUB", 3);
            removeIdentifier(b.name);
        }
    }
    else if(a.type == "IDE" && b.type == "ARR") {
        if(bIndex.type == "NUM") {
            long long int addr = b.mem + stoll(bIndex.name) + 1;
            memToRegister(a.mem);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUB", addr);
            removeIdentifier(bIndex.name);
        }
        else if(bIndex.type == "IDE") {
            memToRegister(b.mem);
            pushCommandOneArg("ADD", bIndex.mem);
            registerToMem(1);
            memToRegister(a.mem);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUBI", 1);
        }
    }
    else if(a.type == "ARR" && b.type == "IDE") {
        if(aIndex.type == "NUM") {
            long long int addr = a.mem + stoll(aIndex.name) + 1;
            memToRegister(addr);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUB", b.mem);
            removeIdentifier(aIndex.name);
        }
        else if(aIndex.type == "IDE") {
            memToRegister(a.mem);
            pushCommandOneArg("ADD", aIndex.mem);
            registerToMem(1);
            pushCommandOneArg("LOADI", 1);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUB", b.mem);
        }
    }
    else if(a.type == "ARR" && b.type == "ARR") {
        if(aIndex.type == "NUM" && bIndex.type == "NUM") {
            long long int addrA = a.mem + stoll(aIndex.name) + 1;
            long long int addrB = b.mem + stoll(bIndex.name) + 1;
            memToRegister(addrA);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUB", addrB);
        }
        else if(aIndex.type == "NUM" && bIndex.type == "IDE") {
            long long int addrA = a.mem + stoll(aIndex.name) + 1;
            memToRegister(b.mem);
            pushCommandOneArg("ADD", bIndex.mem);
            registerToMem(1);
            memToRegister(addrA);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUBI", 1);
        }
        else if(aIndex.type == "IDE" && bIndex.type == "NUM") {
            long long int addrB = b.mem + stoll(bIndex.name) + 1;
            memToRegister(a.mem);
            pushCommandOneArg("ADD", aIndex.mem);
            registerToMem(1);
            pushCommandOneArg("LOADI", 1);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUB", addrB);
        }
        else if(aIndex.type == "IDE" && bIndex.type == "IDE") {
            memToRegister(a.mem);
            pushCommandOneArg("ADD", aIndex.mem);
            registerToMem(1);
            memToRegister(b.mem);
            pushCommandOneArg("ADD", bIndex.mem);
            registerToMem(0);
            pushCommandOneArg("LOADI", 1);
            if(isINC)
                pushCommand("INC");
            pushCommandOneArg("SUBI", 0);
        }
    }
}

void addInt(long long int command, long long int val) {
    codeStack.at(command) = codeStack.at(command) + " " + to_string(val);
}

void setRegister(string number) {
    long long int n = stoll(number);
	/*if (n == registerValue) {
		return;
	}*/
    string bin = decToBin(n);
	long long int limit = bin.size();
    zeroRegister();
	for(long long int i = 0; i < limit; ++i){
		if(bin[i] == '1'){
			pushCommand("INC");
			/*registerValue++;*/
		}
		if(i < (limit - 1)){
	        pushCommand("SHL");
	        /*registerValue *= 2;*/
		}
	}
}

void zeroRegister() {
	/*if(registerValue != 0){*/
		pushCommand("ZERO");
		/*registerValue = 0;*/
	/*}*/
}

void memToRegister(long long int mem) {
	pushCommandOneArg("LOAD", mem);
	/*registerValue = -1;*/
}

string decToBin(long long int n) {
    string r;
    while(n!=0) {r=(n%2==0 ?"0":"1")+r; n/=2;}
    return r;
}

void registerToMem(long long int mem) {
	pushCommandOneArg("STORE", mem);
}

void insertIdentifier(string key, Identifier i) {
    identifierStack.insert(make_pair(key, i));
    memCounter++;
}

void removeIdentifier(string key) {
    identifierStack.erase(key);
    memCounter--;
}

void pushCommand(string str) {
    codeStack.push_back(str);
}

void pushCommandOneArg(string str, long long int num) {
    string temp = str + " " + to_string(num);
    codeStack.push_back(temp);
}

void printCode(string outFileName) {
    ofstream out_code(outFileName);
	long long int i;
	for(i = 0; i < codeStack.size(); i++)
        out_code << codeStack.at(i) << endl;
}

void printCodeStd() {
	long long int i;
	for(i = 0; i < codeStack.size(); i++)
        cout << codeStack.at(i) << endl;
}

void parser(long long int argv, char* argc[]) {
	assignFlag = 1;
	memCounter = 12;
    /*registerValue = -1;*/
	writeFlag = 0;
    depth = 0;

	yyparse();

    string file = "";
    if(argv < 2)
        /*file = "out";*/
        printCodeStd();
    else {
        file = argc[1];
        printCode(file);
    }
}

int main(int argv, char* argc[]){
	parser(argv, argc);
	return 0;
}

int yyerror(string str){
    cout << "Błąd [okolice linii " << yylineno << \
    "]: " << str << endl;
	return 1;
}
