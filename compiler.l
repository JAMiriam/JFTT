%option noyywrap
%option yylineno
%{
    #include <stdlib.h>
    #include <string.h>
    #include "compiler.tab.h"
%}

%x CMT

%%

"("             { BEGIN(CMT);       }
<CMT>")"        { BEGIN(INITIAL);   }
<CMT>(\n|.)
<CMT><<EOF>>    { printf("Błąd: niezakończony komentarz.\n"); yyterminate(); }

"VAR"           { return VAR;      }
"BEGIN"         { return BEG;      }
"END"           { return END;      }

":="            { return ASG;      }
"IF"            { return IF;       }
"THEN"          { return THEN;     }
"ELSE"          { return ELSE;     }
"WHILE"         { return WHILE;    }
"FOR"           { return FOR;      }
"FROM"          { return FROM;     }
"TO"            { return TO;       }
"DOWNTO"        { return DOWNTO;   }
"ENDIF"         { return ENDIF;    }
"ENDWHILE"      { return ENDWHILE; }
"ENDFOR"        { return ENDFOR;   }
"DO"            { return DO;       }
"WRITE"         { return WRITE;    }
"READ"          { return READ;     }

"="             { return EQ;       }
"<"             { return LT;       }
">"             { return GT;       }
"<="            { return LE;       }
">="            { return GE;       }
"<>"            { return NE;       }

"+"             { return ADD;      }
"-"             { return SUB;      }
"*"             { return MUL;      }
"/"             { return DIV;      }
"%"             { return MOD;      }
"["             { return LB;       }
"]"             { return RB;       }

[0-9]+          { yylval.str = (char *)strdup(yytext);
                    return NUM;    }
[_a-z]+         { yylval.str = (char *)strdup(yytext);
                    return IDE;    }

";"             { return SEM;      }
[ \t\r\n]+
.

%%
