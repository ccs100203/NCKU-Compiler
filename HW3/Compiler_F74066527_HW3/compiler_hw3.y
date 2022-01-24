/*	Definition section */
%{
    #include "common.h" //Extern variables that communicate with lex
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    #define MAX_SCOPE 20
    #define false 0
    #define true 1
    #define bool int
    typedef struct Node
    {
        char name[20];
        char type[20];
        int address;
        int lineno;
        char element_type[20];
    } NODE;

    /* Global variables */
    bool HAS_ERROR = false;

    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
        HAS_ERROR = true;
    }

    /* Symbol table function - you can add new function if needed. */
    static void create_symbol();
    static void insert_symbol(char* name, char* type, char* element_type, bool need_init);
    //flag: 1 is all table, 0 is current table
    static NODE lookup_symbol(char* name, int flag);
    static void dump_symbol(int scope);
    static char* get_type(char* name);
    //flag: 1 is println, 0 is print
    static void print_j(char* type, int flag);

    //current scope index
    int cs_idx = 0; 

    int table_len[MAX_SCOPE] = {0}; // each table len
    NODE table[MAX_SCOPE][50]; // symbol table
    int address = 0;  
    
    // current type
    char now_type[10] = "none";
    // current operator
    char now_op[10] = "none";
    NODE *global_node;

    FILE* fptr;
    // record curret cmp label
    int cmp_num = 1;
    // record curret for label
    int for_num = 1;
    // record curret for label
    int if_num = 1;

    // record the level inside in if
    int level_if = 0;
    // record prev if_num
    int prev_if = 0;
    // record exit num
    int num_if_exit = 1;

    // record is ForClause 
    int num_ForClause = 0;
    // record the level inside in for
    int level_for = 0;
    // record prev for_num
    int prev_for = 0;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
    /* ... */
}

/* Token without return */
%token VAR
%token INT FLOAT BOOL STRING

%token INC DEC GEQ LEQ EQL NEQ
%token ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token TRUE FALSE



/* Token with return, which need to sepcify type */
%token <s_val> INT_LIT
%token <s_val> FLOAT_LIT
%token <s_val> STRING_LIT 
%token <s_val> BOOL_LIT
%token <s_val> IDENT NEWLINE
%token <s_val> LAND LOR PRINT PRINTLN 
%token <s_val> IF ELSE FOR

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type TypeName ArrayType 
%type <s_val> Expression PrimaryExpr Literal Operand IndexExpr ConversionExpr UnaryExpr
%type <s_val> add_op mul_op cmp_op unary_op assign_op
%type <s_val> LandExpr ComparisonExpr AdditionExpr MultiplyExpr 
%type <s_val> PrintStmt AssignmentStmt SimpleStmt ExpressionStmt
%type <s_val> ForClause Condition InitStmt PostStmt ForStmt IfStmt
%type <s_val> left_Stmt Block for_behind if_behind else_behind

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : StatementList {;}
;

StatementList
    : StatementList Statement
    | Statement
;

Type
    : TypeName {$$ = $1;}
    | ArrayType {$$ = $1;}
;

TypeName 
    : INT {$$ = "int32";}
    | FLOAT {$$ = "float32";}
    | STRING {$$ = "string";}
    | BOOL {$$ = "bool";}
;

ArrayType 
    : '[' Expression { strcpy(now_type, "none");} ']' Type { strcpy(now_type, "none"); 
    char tmp[10]="A"; strcat(tmp, $5); $$=tmp;}
;

Expression 
    : LandExpr { ; }
    | Expression LOR LandExpr { $$="bool"; strcpy(now_type, "bool");
        if( 0 == strncmp($1, "int32", strlen("int32")) || 0 == strncmp($3, "int32", strlen("int32"))){
            yyerror("invalid operation: (operator LOR not defined on int32)");
            strcpy(now_type, "none");
        }
        if( 0 == strncmp($1, "float32", strlen("float32")) || 0 == strncmp($3, "float32", strlen("float32")) ){
            yyerror("invalid operation: (operator LOR not defined on float32)");
            strcpy(now_type, "none");
        }
        fprintf(fptr, "\tior\n");
        printf("LOR\n"); }
;

LandExpr
    : ComparisonExpr { ; }
    | LandExpr LAND ComparisonExpr { $$="bool"; strcpy(now_type, "bool");
        if( 0 == strncmp($1, "int32", strlen("int32")) || 0 == strncmp($3, "int32", strlen("int32"))){
            yyerror("invalid operation: (operator LAND not defined on int32)");
            strcpy(now_type, "none");
        }
        if( 0 == strncmp($1, "float32", strlen("float32")) || 0 == strncmp($3, "float32", strlen("float32")) ){
            yyerror("invalid operation: (operator LAND not defined on float32)");
            strcpy(now_type, "none");
        }
        fprintf(fptr, "\tiand\n");
        printf("LAND\n"); }
;

ComparisonExpr
    : AdditionExpr { ; }
    | ComparisonExpr cmp_op AdditionExpr { $$=$2; printf("%s\n", $2);
        // compare operator
        if(0==strcmp($2, "EQL")){
            if(0==strcmp(now_type, "int32")){
                fprintf(fptr, "\tisub\n");
                fprintf(fptr, "\tifeq L%d_cmp_0\n", cmp_num);
                fprintf(fptr, "\ticonst_0\n");
                fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
                fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
                fprintf(fptr, "\ticonst_1\n");
                fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
                cmp_num++;
            }else{
                fprintf(fptr, "\tfcmpl\n");
                fprintf(fptr, "\tifeq L%d_cmp_0\n", cmp_num);
                fprintf(fptr, "\ticonst_0\n");
                fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
                fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
                fprintf(fptr, "\ticonst_1\n");
                fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
                cmp_num++;
            }
        }else if(0==strcmp($2, "NEQ")){
            if(0==strcmp(now_type, "int32")){
                fprintf(fptr, "\tisub\n");
                fprintf(fptr, "\tifne L%d_cmp_0\n", cmp_num);
                fprintf(fptr, "\ticonst_0\n");
                fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
                fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
                fprintf(fptr, "\ticonst_1\n");
                fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
                cmp_num++;
            }else{
                fprintf(fptr, "\tfcmpl\n");
                fprintf(fptr, "\tifne L%d_cmp_0\n", cmp_num);
                fprintf(fptr, "\ticonst_0\n");
                fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
                fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
                fprintf(fptr, "\ticonst_1\n");
                fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
                cmp_num++;
            }
        }else if(0==strcmp($2, "LSS")){
            if(0==strcmp(now_type, "int32")){
                fprintf(fptr, "\tisub\n");
                fprintf(fptr, "\tiflt L%d_cmp_0\n", cmp_num);
                fprintf(fptr, "\ticonst_0\n");
                fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
                fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
                fprintf(fptr, "\ticonst_1\n");
                fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
                cmp_num++;
            }else{
                fprintf(fptr, "\tfcmpl\n");
                fprintf(fptr, "\tiflt L%d_cmp_0\n", cmp_num);
                fprintf(fptr, "\ticonst_0\n");
                fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
                fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
                fprintf(fptr, "\ticonst_1\n");
                fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
                cmp_num++;
            }
        }else if(0==strcmp($2, "LEQ")){
            if(0==strcmp(now_type, "int32")){
                fprintf(fptr, "\tisub\n");
                fprintf(fptr, "\tifle L%d_cmp_0\n", cmp_num);
                fprintf(fptr, "\ticonst_0\n");
                fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
                fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
                fprintf(fptr, "\ticonst_1\n");
                fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
                cmp_num++;
            }else{
                fprintf(fptr, "\tfcmpl\n");
                fprintf(fptr, "\tifle L%d_cmp_0\n", cmp_num);
                fprintf(fptr, "\ticonst_0\n");
                fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
                fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
                fprintf(fptr, "\ticonst_1\n");
                fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
                cmp_num++;
            }
        }else if(0==strcmp($2, "GTR")){
            if(0==strcmp(now_type, "int32")){
                fprintf(fptr, "\tisub\n");
                fprintf(fptr, "\tifgt L%d_cmp_0\n", cmp_num);
                fprintf(fptr, "\ticonst_0\n");
                fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
                fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
                fprintf(fptr, "\ticonst_1\n");
                fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
                cmp_num++;
            }else{
                fprintf(fptr, "\tfcmpl\n");
                fprintf(fptr, "\tifgt L%d_cmp_0\n", cmp_num);
                fprintf(fptr, "\ticonst_0\n");
                fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
                fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
                fprintf(fptr, "\ticonst_1\n");
                fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
                cmp_num++;
            }
        }else if(0==strcmp($2, "GEQ")){
            if(0==strcmp(now_type, "int32")){
                fprintf(fptr, "\tisub\n");
                fprintf(fptr, "\tifge L%d_cmp_0\n", cmp_num);
                fprintf(fptr, "\ticonst_0\n");
                fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
                fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
                fprintf(fptr, "\ticonst_1\n");
                fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
                cmp_num++;
            }else{
                fprintf(fptr, "\tfcmpl\n");
                fprintf(fptr, "\tifge L%d_cmp_0\n", cmp_num);
                fprintf(fptr, "\ticonst_0\n");
                fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
                fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
                fprintf(fptr, "\ticonst_1\n");
                fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
                cmp_num++;
            }
        }
        strcpy(now_type, "bool");
    }
;

AdditionExpr
    : MultiplyExpr { ; }
    | AdditionExpr add_op MultiplyExpr { 
    if( 0 != strncmp("none", now_type, strlen(now_type)) && 0 != strcmp("POS", get_type($1))
    && 0 != strcmp("NEG", get_type($1)) && 0 != strcmp("bool", now_type) ){
        if( 0 != strcmp(get_type($1), now_type) ){
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, now_op, get_type($1), now_type);
            HAS_ERROR = true;
        }
    }
    printf("%s\n", $2); 
    if(0==strcmp($2, "ADD")){
        if(0==strcmp("int32", now_type)){
            fprintf(fptr, "\tiadd\n");
        }else{
            fprintf(fptr, "\tfadd\n");
        }
    }else{
        if(0==strcmp("int32", now_type)){
            fprintf(fptr, "\tisub\n");
        }else{
            fprintf(fptr, "\tfsub\n");
        }
    }}
;

MultiplyExpr
    : UnaryExpr { ; }
    | MultiplyExpr mul_op UnaryExpr { 
    if( 0 == strncmp($2, "REM", strlen("REM")) ){
        if( 0 == strncmp(get_type($1), "float32", strlen("float32")) || 0 == strncmp(get_type($3), "float32", strlen("float32"))){
            yyerror("invalid operation: (operator REM not defined on float32)");
            strcpy(now_type, "none");
        }
    } printf("%s\n", $2); 
    if(0==strcmp($2, "MUL")){
        if(0==strcmp("int32", now_type)){
            fprintf(fptr, "\timul\n");
        }else{
            fprintf(fptr, "\tfmul\n");
        }
    }else if(0==strcmp($2, "QUO")){
        if(0==strcmp("int32", now_type)){
            fprintf(fptr, "\tidiv\n");
        }else{
            fprintf(fptr, "\tfdiv\n");
        }
    }else{
        fprintf(fptr, "\tirem\n");
    }}
;

UnaryExpr 
    : PrimaryExpr           { ; }
    | unary_op UnaryExpr    { printf("%s\n", $1); 
    if(0==strcmp($1, "NEG")){
        if(0==strcmp("int32", now_type)){
            fprintf(fptr, "\tineg\n");
        }else{
            fprintf(fptr, "\tfneg\n");
        }
    }else if(0==strcmp($1, "NOT")){
        fprintf(fptr, "\ticonst_1\n");
        fprintf(fptr, "\tixor\n");
    }}
;

cmp_op 
    : EQL { $$ = "EQL"; }
    | NEQ { $$ = "NEQ"; }
    | '<' { $$ = "LSS"; }
    | LEQ { $$ = "LEQ"; }
    | '>' { $$ = "GTR"; }
    | GEQ { $$ = "GEQ"; }
;
add_op 
    : '+' { $$ = "ADD"; strcpy(now_op, "ADD"); }
    | '-' { $$ = "SUB"; strcpy(now_op, "SUB"); }
;
mul_op 
    : '*' { $$ = "MUL"; strcpy(now_op, "MUL"); }
    | '/' { $$ = "QUO"; strcpy(now_op, "QUO"); }
    | '%' { $$ = "REM"; }
;
unary_op 
    : '+' { $$ = "POS"; }
    | '-' { $$ = "NEG"; }
    | '!' { $$ = "NOT"; }
;

PrimaryExpr 
    : Operand { $$=$1; }
    | IndexExpr { ; }
    | ConversionExpr { ; }
;
Operand 
    : Literal { $$=$1; }
    | IDENT { NODE tmp = lookup_symbol($1, 1); 
        if( tmp.address != -1){
            printf("IDENT (name=%s, address=%d)\n", $1, tmp.address);
            // fprintf(fptr,"IDENT (name=%s, address=%d)\n", $1, tmp.address);
            
            if(0==strcmp(tmp.type, "int32")){
                fprintf(fptr, "\tiload %d\n", tmp.address);
            }else if(0==strcmp(tmp.type, "float32")){
                fprintf(fptr, "\tfload %d\n", tmp.address);
            }else if(0==strcmp(tmp.type, "string")){
                fprintf(fptr, "\taload %d\n", tmp.address);
            }else if(0==strcmp(tmp.type, "array")){
                fprintf(fptr, "\taload %d\n", tmp.address);
            }else if(0==strcmp(tmp.type, "bool")){
                fprintf(fptr, "\tiload %d\n", tmp.address);
            }
            
            // printf("-------- %s now %s\n", tmp.type, now_type);
            strcpy(now_type, tmp.type);
            // marked
            if( 0==strcmp(tmp.type, "array") ){
                strcpy(now_type, "none");
            }
        }else{
            printf("error:%d: undefined: %s\n", yylineno+1, $1);
            HAS_ERROR = true;
            // yyerror("not this symbol??"); 
        }}
    | '(' Expression ')'  { ; }
;
Literal 
    : INT_LIT { $$="int32"; printf("INT_LIT %s\n", $1); 
        fprintf(fptr, "\tldc %s\n", $1);
        if(0 == strncmp(now_type, "none", strlen(now_type))){
            strcpy(now_type, "int32");
        }else if(0 == strncmp(now_type, "float32", strlen(now_type))){
            strcpy(now_type, "int32");
            // yyerror("type error");
        }}
    | FLOAT_LIT { $$="float32"; 
        printf("FLOAT_LIT %f\n", atof($1));
        fprintf(fptr, "\tldc %f\n", atof($1));
        if(0 == strncmp(now_type, "none", strlen(now_type))){
            strcpy(now_type, "float32");
        }else if(0 == strncmp(now_type, "int32", strlen(now_type))){
            strcpy(now_type, "float32");
            // yyerror("type error");
        }} 
    | BOOL_LIT { $$="bool"; 
        if(0==strcmp($1,"TRUE")){
            fprintf(fptr, "\ticonst_1\n");
        }else{
            fprintf(fptr, "\ticonst_0\n");
        }
        printf("%s\n", $1); strcpy(now_type, "bool"); }
    | '"' STRING_LIT '"' { $$="string"; fprintf(fptr, "\tldc \"%s\"\n", $2); 
        printf("STRING_LIT %s\n", $2); strcpy(now_type, "string"); }
;

IndexExpr 
    : PrimaryExpr '[' Expression ']' {
        NODE tmp = lookup_symbol($1, 1);
        if(0==strcmp(tmp.element_type, "int32")){
            fprintf(fptr, "\tiaload\n");
        }else{
            fprintf(fptr, "\tfaload\n");
        }
        strcpy(now_type, "none");}
;
ConversionExpr 
    : Type '(' Expression ')' {
    if(0==strncmp($3, "int32", strlen("int32")) || 0==strncmp($3, "float32", strlen("float32")) 
    || 0==strncmp($3, "bool", strlen("bool")) || 0==strncmp($3, "string", strlen("string")) ){
        printf("%c to %c\n", $3[0]&0x5f, $1[0]&0x5f);
        fprintf(fptr, "\t%c2%c\n", $3[0], $1[0]);
    }else{
        NODE tmp = lookup_symbol($3, 1);
        if(tmp.address == -1){
            yyerror("print none symbol");
        }else if(0==strncmp(tmp.type, "array", strlen(tmp.type))){
            printf("%c to %c\n", tmp.element_type[0]&0x5f, $1[0]&0x5f);
            fprintf(fptr, "\t%c2%c\n", tmp.element_type[0], $1[0]);
        }else{
            printf("%c to %c\n", tmp.type[0]&0x5f, $1[0]&0x5f);
            fprintf(fptr, "\t%c2%c\n", tmp.type[0], $1[0]);
        }
    }
    strcpy(now_type, $1); }
;

Statement 
    : DeclarationStmt NEWLINE
    | SimpleStmt NEWLINE
    | Block NEWLINE
    |  { level_if++; } IfStmt NEWLINE 
    |  { level_for++; } ForStmt NEWLINE { level_for--; }
    | PrintStmt NEWLINE
    | NEWLINE
;
SimpleStmt 
    : AssignmentStmt { strcpy(now_type, "none"); }
    | ExpressionStmt { strcpy(now_type, "none"); }
    | IncDecStmt { strcpy(now_type, "none"); }
;

DeclarationStmt 
    :VAR IDENT Type '=' Expression { 
    if($3[0] != 'A'){
        insert_symbol($2, $3, "-", 0); 
    }else{
        insert_symbol($2, "array", $3+1, 0); 
    }
    strcpy(now_type, "none");}
    
    | VAR IDENT Type {
    if($3[0] != 'A'){
        insert_symbol($2, $3, "-", 1); 
    }else{
        insert_symbol($2, "array", $3+1, 0); 
    }
    strcpy(now_type, "none");}
;

AssignmentStmt 
    : left_Stmt assign_op Expression { 
    if( 0 != strcmp(get_type($1), "none") && 0 != strcmp("none", now_type) && 0 != strcmp(get_type($1), now_type)){
        printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $2, get_type($1), now_type);
        HAS_ERROR = true;
    }else if(0 == strcmp($1, "int32")){
        yyerror("cannot assign to int32");
    }
    printf("%s\n", $2);
    NODE tmp = lookup_symbol($1, 1);
    // for += -= *= /= %=
    if( 0==strcmp($2, "ADD_ASSIGN") ){
        if(0==strcmp(tmp.type, "int32")){
            fprintf(fptr, "\tiload %d\n", tmp.address);
            fprintf(fptr, "\tswap\n");
            fprintf(fptr, "\tiadd\n");
        }else if(0==strcmp(tmp.type, "float32")){
            fprintf(fptr, "\tfload %d\n", tmp.address);
            fprintf(fptr, "\tswap\n");
            fprintf(fptr, "\tfadd\n");
        }
    }else if( 0==strcmp($2, "SUB_ASSIGN") ){
        if(0==strcmp(tmp.type, "int32")){
            fprintf(fptr, "\tiload %d\n", tmp.address);
            fprintf(fptr, "\tswap\n");
            fprintf(fptr, "\tisub\n");
        }else if(0==strcmp(tmp.type, "float32")){
            fprintf(fptr, "\tfload %d\n", tmp.address);
            fprintf(fptr, "\tswap\n");
            fprintf(fptr, "\tfsub\n");
        }
    }else if( 0==strcmp($2, "MUL_ASSIGN") ){
        if(0==strcmp(tmp.type, "int32")){
            fprintf(fptr, "\tiload %d\n", tmp.address);
            fprintf(fptr, "\tswap\n");
            fprintf(fptr, "\timul\n");
        }else if(0==strcmp(tmp.type, "float32")){
            fprintf(fptr, "\tfload %d\n", tmp.address);
            fprintf(fptr, "\tswap\n");
            fprintf(fptr, "\tfmul\n");
        }
    }else if( 0==strcmp($2, "QUO_ASSIGN") ){
        if(0==strcmp(tmp.type, "int32")){
            fprintf(fptr, "\tiload %d\n", tmp.address);
            fprintf(fptr, "\tswap\n");
            fprintf(fptr, "\tidiv\n");
        }else if(0==strcmp(tmp.type, "float32")){
            fprintf(fptr, "\tfload %d\n", tmp.address);
            fprintf(fptr, "\tswap\n");
            fprintf(fptr, "\tfdiv\n");
        }
    }else if( 0==strcmp($2, "REM_ASSIGN") ){
        if(0==strcmp(tmp.type, "int32")){
            fprintf(fptr, "\tiload %d\n", tmp.address);
            fprintf(fptr, "\tswap\n");
            fprintf(fptr, "\tirem\n");
        }
    }

    // store
    if(0==strcmp(tmp.type, "int32")){
        fprintf(fptr, "\tistore %d\n", tmp.address);
    }else if(0==strcmp(tmp.type, "float32")){
        fprintf(fptr, "\tfstore %d\n", tmp.address);
    }else if(0==strcmp(tmp.type, "string")){
        fprintf(fptr, "\tastore %d\n", tmp.address);
    }else if(0==strcmp(tmp.type, "array")){
        if(0==strcmp(tmp.element_type, "int32")){
            fprintf(fptr, "\tiastore\n\n");
        }else{
            fprintf(fptr, "\tfastore\n\n");
        }
    }else if(0==strcmp(tmp.type, "bool")){
        fprintf(fptr, "\tistore %d\n", tmp.address);
    }
    /* printf("AssignmentStmt %s %s %s now %s\n", $1,$2,$3, now_type); */
    }
;
assign_op 
    : '=' { $$="ASSIGN"; }
    | ADD_ASSIGN { $$="ADD_ASSIGN"; }
    | SUB_ASSIGN { $$="SUB_ASSIGN"; }
    | MUL_ASSIGN { $$="MUL_ASSIGN"; }
    | QUO_ASSIGN { $$="QUO_ASSIGN"; }
    | REM_ASSIGN { $$="REM_ASSIGN"; }
;

ExpressionStmt 
    : Expression 
;

IncDecStmt 
    : Expression INC { printf("INC\n"); 
        NODE tmp = lookup_symbol($1, 1); 
        if(0==strcmp(tmp.type, "int32")){
            fprintf(fptr, "\tldc 1\n");
            fprintf(fptr, "\tiadd\n");
            fprintf(fptr, "\tistore %d\n", tmp.address);
        }else{
            fprintf(fptr, "\tldc 1.0\n");
            fprintf(fptr, "\tfadd\n");
            fprintf(fptr, "\tfstore %d\n", tmp.address);
        }}
    | Expression DEC { printf("DEC\n");
        NODE tmp = lookup_symbol($1, 1); 
        if(0==strcmp(tmp.type, "int32")){
            fprintf(fptr, "\tldc 1\n");
            fprintf(fptr, "\tisub\n");
            fprintf(fptr, "\tistore %d\n", tmp.address);
        }else{
            fprintf(fptr, "\tldc 1.0\n");
            fprintf(fptr, "\tfsub\n");
            fprintf(fptr, "\tfstore %d\n", tmp.address);
        }}
;

Block 
    : '{' { create_symbol(); } StatementList '}' { dump_symbol(cs_idx); }
;

IfStmt 
    : IF {if_num++; if(level_if==1){ prev_if = if_num; } } 
    Condition { fprintf(fptr,"\tifeq L%d_if_false \n", if_num); } if_behind
;

if_behind
    : Block { fprintf(fptr,"\tgoto L%d_if_exit\n", num_if_exit); } ELSE { fprintf(fptr,"L%d_if_false:\n", if_num);} else_behind 
    | Block { fprintf(fptr,"\tgoto L%d_if_exit\n", num_if_exit); 
        // judge which if level
        if(level_if==1){
            fprintf(fptr,"L%d_if_false:\n", prev_if); 
        }else{
            fprintf(fptr,"L%d_if_false:\n", if_num); 
        }
        fprintf(fptr,"L%d_if_exit:\n", num_if_exit);}
;

else_behind
    : IfStmt
    | Block { fprintf(fptr,"L%d_if_exit:\n", num_if_exit); num_if_exit++; level_if--; }
;

Condition : Expression {
    if( 0 != strcmp("none", get_type($1)) ){
        if( 0 == strcmp("int32", get_type($1)) || 0 == strcmp("float32", get_type($1)) ){
            printf("error:%d: non-bool (type %s) used as for condition\n", yylineno+1, get_type($1));
            HAS_ERROR = true;
        }
    }
    }
;

ForStmt 
    : FOR { for_num++; if(level_for==1){ prev_for = for_num; } fprintf(fptr, "L%d_for_begin:\n", for_num); } 
    for_behind  { 
        // if it's ForClause
        if(num_ForClause>0){
            if(level_for == 1){
                fprintf(fptr, "\tgoto L%d_for_Post\n", prev_for); 
            }else{
                fprintf(fptr, "\tgoto L%d_for_Post\n", for_num); 
            }
        }else{
            if(level_for == 1){
                fprintf(fptr, "\tgoto L%d_for_begin\n", prev_for); 
            }else{
                fprintf(fptr, "\tgoto L%d_for_begin\n", for_num); 
            }
        }

        // if has multi level for loop
        if(level_for == 1){
            fprintf(fptr, "L%d_for_exit:\n", prev_for); 
        }else{
            fprintf(fptr, "L%d_for_exit:\n", for_num);
        }
        num_ForClause--;
    }
;

for_behind
    : Condition { fprintf(fptr,"\tifeq L%d_for_exit \n", for_num); } Block 
    | ForClause { fprintf(fptr, "L%d_for_Block:\n", for_num); } Block 
;

ForClause 
    : InitStmt { num_ForClause++; fprintf(fptr, "L%d_for_Condition:\n", for_num);} ';' 
    Condition { fprintf(fptr,"\tifeq L%d_for_exit \n", for_num); fprintf(fptr,"\tgoto L%d_for_Block \n", for_num); } ';' 
    { fprintf(fptr, "L%d_for_Post:\n", for_num); } PostStmt { fprintf(fptr,"\tgoto L%d_for_Condition \n", for_num); } 
;
InitStmt 
    : SimpleStmt
;
PostStmt 
    : SimpleStmt
;

PrintStmt 
    : PRINT '(' Expression ')' {
    if(0==strncmp($3, "int32", strlen("int32")) || 0==strncmp($3, "float32", strlen("float32")) 
    || 0==strncmp($3, "bool", strlen("bool")) || 0==strncmp($3, "string", strlen("string")) ){
        printf("PRINT %s\n", $3);
        print_j($3, 0);
    }else{
        NODE tmp = lookup_symbol($3, 1);
        if(tmp.address == -1){
            yyerror("print none symbol");
        }else if(0==strncmp(tmp.type, "array", strlen(tmp.type))){
            printf("PRINT %s\n", tmp.element_type);
            print_j(tmp.element_type, 0);
        }else{
            printf("PRINT %s\n", tmp.type);
            print_j(tmp.type, 0);
        }
    }
    strcpy(now_type, "none");}

    | PRINTLN '(' Expression ')' {
    if(0==strncmp($3, "int32", strlen("int32")) || 0==strncmp($3, "float32", strlen("float32")) 
    || 0==strncmp($3, "bool", strlen("bool")) || 0==strncmp($3, "string", strlen("string")) ){
        printf("PRINTLN %s\n", $3);
        print_j($3, 1);
    }else{
        NODE tmp = lookup_symbol($3, 1);
        if(tmp.address == -1){
            yyerror("print none symbol");
        }else if(0==strncmp(tmp.type, "array", strlen(tmp.type))){
            printf("PRINTLN %s\n", tmp.element_type);
            print_j(tmp.element_type, 1);
        }else{
            printf("PRINTLN %s\n", tmp.type);
            print_j(tmp.type, 1);
        }
    }
    strcpy(now_type, "none");}
;

left_Stmt
    : Literal { $$=$1; }
    | IDENT { NODE tmp = lookup_symbol($1, 1); 
        if( tmp.address != -1){
            printf("IDENT (name=%s, address=%d)\n", $1, tmp.address);
            
            strcpy(now_type, tmp.type);
            // marked
            if( 0==strcmp(tmp.type, "array") ){
                strcpy(now_type, "none");
            }
        }else{
            printf("error:%d: undefined: %s\n", yylineno+1, $1);
            HAS_ERROR = true;
        }}
    | PrimaryExpr '[' Expression ']' { strcpy(now_type, "none");}
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }

    global_node = (NODE*)malloc(sizeof(NODE));
    fptr = fopen("hw3.j", "w");
    fprintf(fptr, ".source hw3.j\n");
    fprintf(fptr, ".class public Main\n");
    fprintf(fptr, ".super java/lang/Object\n");
    fprintf(fptr, ".method public static main([Ljava/lang/String;)V\n");
    fprintf(fptr, ".limit stack 100 ; Define your storage size.\n");
    fprintf(fptr, ".limit locals 100 ; Define your local space number.\n\n");
    
    yylineno = 0;
    yyparse();

    dump_symbol(cs_idx);

	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
    fprintf(fptr, "\treturn\n.end method\n");
    if (HAS_ERROR) {
        remove("hw3.j");
    }
    fclose(fptr);

    return 0;
}

static void create_symbol() {
    cs_idx++;
}

static void insert_symbol(char* name, char* type, char* element_type, bool need_init) {
    NODE tmp = lookup_symbol(name, 0);
    if(tmp.address != -1){
        printf("error:%d: %s redeclared in this block. previous declaration at line %d\n", yylineno, name, tmp.lineno);
        HAS_ERROR = true;
        return;
    }

    if( 0==strcmp(type, "string") ){
        if(need_init == 1){
            fprintf(fptr, "\tldc \"\"\n");
        }
        fprintf(fptr, "\tastore %d\n", address);
    }else if( 0==strcmp(type, "array") ){
        if( 0==strcmp(element_type, "int32") ){
            fprintf(fptr, "\tnewarray int\n");
        }else{
            fprintf(fptr, "\tnewarray float\n");
        }
        fprintf(fptr, "\tastore %d\n", address);
    }else if( 0==strcmp(type, "int32") ){
        if(need_init == 1){
            fprintf(fptr, "\tldc 0\n");
        }
        fprintf(fptr, "\tistore %d\n", address);
    }else if( 0==strcmp(type, "float32") ){
        if(need_init == 1){
            fprintf(fptr, "\tldc 0.0\n");
        }
        fprintf(fptr, "\tfstore %d\n", address);
    }else if( 0==strcmp(type, "bool") ){
        fprintf(fptr, "\tistore %d\n", address);
    }

    strcpy(table[cs_idx][table_len[cs_idx]].name, name);
    strcpy(table[cs_idx][table_len[cs_idx]].type, type);
    table[cs_idx][table_len[cs_idx]].address = address;
    table[cs_idx][table_len[cs_idx]].lineno = yylineno;
    strcpy(table[cs_idx][table_len[cs_idx]].element_type, element_type);
    table_len[cs_idx]++;
    address++;
    printf("> Insert {%s} into symbol table (scope level: %d)\n", name, cs_idx);
}

//flag: 1 is all table, 0 is current table
static NODE lookup_symbol(char* name, int flag) {
    // printf("look up name %s\n", name);
    if(flag == 0){
        for(int j=0; j<table_len[cs_idx]; ++j){
            if(0 == strcmp(table[cs_idx][j].name, name))
                return table[cs_idx][j];
        }
        NODE node;
        node.address = -1;
        return node;
    }
    else{
        for(int i=cs_idx; i>=0; --i){
            for(int j=0; j<table_len[i]; ++j){
                if(0 == strcmp(table[i][j].name, name))
                    return table[i][j];
            }
        }
        NODE node;
        node.address = -1;
        return node;
    }
}

static void dump_symbol(int scope) {
    printf("> Dump symbol table (scope level: %d)\n", scope);
    printf("%-10s%-10s%-10s%-10s%-10s%s\n",
           "Index", "Name", "Type", "Address", "Lineno", "Element type");
    for(int i=0; i<table_len[scope]; ++i){
        printf("%-10d%-10s%-10s%-10d%-10d%s\n",
            i, table[scope][i].name, table[scope][i].type, table[scope][i].address, table[scope][i].lineno, table[scope][i].element_type);
    }
    table_len[cs_idx] = 0;
    cs_idx--;
}

static char* get_type(char* name){
    // printf("get type %s\n", name);
    if( 0==strncmp(name, "int32", strlen("int32")) || 0==strncmp(name, "float32", strlen("float32")) 
    || 0==strncmp(name, "bool", strlen("bool")) || 0==strncmp(name, "string", strlen("string")) 
    || 0==strncmp(name, "NEG", strlen("NEG")) || 0==strncmp(name, "POS", strlen("POS"))
    || 0==strncmp(name, "GTR", strlen("GTR")) || 0==strncmp(name, "LSS", strlen("LSS"))
    || 0==strcmp(name, "NEQ") || 0==strcmp(name, "EQL") )
    {
        return name;
    }else{
        *global_node = lookup_symbol(name, 1);
        if(global_node->address == -1){
            //printf("error:%d: undefined: %s\n", yylineno+1, name);
            return "none";
        }else if(0==strncmp(global_node->type, "array", strlen(global_node->type))){
            return global_node->element_type;
        }else{
            return global_node->type;
        }
    }
}

//flag: 1 is println, 0 is print
static void print_j(char* type, int flag){
    if(flag == 1){
        if(0==strcmp(type, "int32")){
            fprintf(fptr, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n\tinvokevirtual java/io/PrintStream/println(I)V\n\n");
        }else if(0==strcmp(type, "float32")){
            fprintf(fptr, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n\tinvokevirtual java/io/PrintStream/println(F)V\n\n");
        }else if(0==strcmp(type, "bool")){
            fprintf(fptr, "\tifne L%d_cmp_0\n", cmp_num);
            fprintf(fptr, "\tldc \"false\"\n");
            fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
            fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
            fprintf(fptr, "\tldc \"true\"\n");
            fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
            fprintf(fptr, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n\n");
            cmp_num++;
        }else if(0==strcmp(type, "string")){
            fprintf(fptr, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n\n");
        }else{
            printf("NNNNNTYPEEEE: %s\n", type);
        }
    }else{
        if(0==strcmp(type, "int32")){
            fprintf(fptr, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n\tinvokevirtual java/io/PrintStream/print(I)V\n\n");
        }else if(0==strcmp(type, "float32")){
            fprintf(fptr, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n\tinvokevirtual java/io/PrintStream/print(F)V\n\n");
        }else if(0==strcmp(type, "bool")){
            fprintf(fptr, "\tifne L%d_cmp_0\n", cmp_num);
            fprintf(fptr, "\tldc \"false\"\n");
            fprintf(fptr, "\tgoto L%d_cmp_1\n", cmp_num);
            fprintf(fptr, "L%d_cmp_0:\n", cmp_num);
            fprintf(fptr, "\tldc \"true\"\n");
            fprintf(fptr, "L%d_cmp_1:\n", cmp_num);
            fprintf(fptr, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n\n");
            cmp_num++;
        }else if(0==strcmp(type, "string")){
            fprintf(fptr, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n\n");
        }else{
            printf("NNNNNTYPEEEE: %s\n", type);
        }
    }
}