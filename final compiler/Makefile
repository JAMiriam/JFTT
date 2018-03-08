make: opt_compiler.y opt_compiler.l
	bison -d opt_compiler.y
	flex opt_compiler.l
	g++ -std=c++11 -o compiler lex.yy.c opt_compiler.tab.c -lfl
