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

    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    /* Symbol table function - you can add new function if needed. */
    static void create_symbol();
    static void insert_symbol(char* name, char* type, char* element_type);
    static NODE lookup_symbol(char* name, int flag);
    static void dump_symbol(int scope);
    static char* get_type(char* name);

    /* Global variables */
    bool HAS_ERROR = false;

    int cs_idx = 0; //current scope index

    // int scope_level[MAX_SCOPE] = {0}; // each table scope
    int table_len[MAX_SCOPE] = {0}; // each table len
    NODE table[MAX_SCOPE][50]; // symbol table
    int address = 0;  
    
    char now_type[10] = "none";
    char now_op[10] = "none";
    NODE *global_node;
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
%type <s_val> ForClause Condition InitStmt PostStmt ForStmt
%type <s_val> left_Stmt

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
    printf("LAND\n"); }
;

ComparisonExpr
    : AdditionExpr { ; }
    | ComparisonExpr cmp_op AdditionExpr { $$=$2; printf("%s\n", $2); strcpy(now_type, "bool");}
;

AdditionExpr
    : MultiplyExpr { ; }
    | AdditionExpr add_op MultiplyExpr { 
    if( 0 != strncmp("none", now_type, strlen(now_type)) && 0 != strcmp("POS", get_type($1))
    && 0 != strcmp("NEG", get_type($1)) && 0 != strcmp("bool", now_type) ){
        if( 0 != strcmp(get_type($1), now_type) )
            printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, now_op, get_type($1), now_type);
    }
    printf("%s\n", $2); }
;

MultiplyExpr
    : UnaryExpr { ; }
    | MultiplyExpr mul_op UnaryExpr { 
    if( 0 == strncmp($2, "REM", strlen("REM")) ){
        if( 0 == strncmp(get_type($1), "float32", strlen("float32")) || 0 == strncmp(get_type($3), "float32", strlen("float32"))){
            yyerror("invalid operation: (operator REM not defined on float32)");
            strcpy(now_type, "none");
        }
    } printf("%s\n", $2); }
;

UnaryExpr 
    : PrimaryExpr           { ; }
    | unary_op UnaryExpr    { printf("%s\n", $1); }
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
                // printf("-------- %s now %s\n", tmp.type, now_type);
                
                strcpy(now_type, tmp.type);
                // marked
                if( 0==strcmp(tmp.type, "array") ){
                    strcpy(now_type, "none");
                }
            }else{
                printf("error:%d: undefined: %s\n", yylineno+1, $1);
                // yyerror("not this symbol??"); 
            }}
    | '(' Expression ')'  { ; }
;
Literal 
    : INT_LIT { $$="int32"; printf("INT_LIT %s\n", $1); 
        if(0 == strncmp(now_type, "none", strlen(now_type))){
            strcpy(now_type, "int32");
            
        }else if(0 == strncmp(now_type, "float32", strlen(now_type))){
            strcpy(now_type, "int32");
            // yyerror("type error");
        }}
    | FLOAT_LIT { $$="float32"; 
        printf("FLOAT_LIT %f\n", atof($1));
        if(0 == strncmp(now_type, "none", strlen(now_type))){
            strcpy(now_type, "float32");
            
        }else if(0 == strncmp(now_type, "int32", strlen(now_type))){
            strcpy(now_type, "float32");
            // yyerror("type error");
        }} 
    | BOOL_LIT { $$="bool"; printf("%s\n", $1); strcpy(now_type, "bool"); }
    | '"' STRING_LIT '"' { $$="string"; printf("STRING_LIT %s\n", $2); strcpy(now_type, "string"); }
;

IndexExpr 
    : PrimaryExpr '[' Expression ']' { strcpy(now_type, "none");}
;
ConversionExpr 
    : Type '(' Expression ')' {
    if(0==strncmp($3, "int32", strlen("int32")) || 0==strncmp($3, "float32", strlen("float32")) 
    || 0==strncmp($3, "bool", strlen("bool")) || 0==strncmp($3, "string", strlen("string")) ){
        printf("%c to %c\n", $3[0]&0x5f, $1[0]&0x5f);
    }else{
        NODE tmp = lookup_symbol($3, 1);
        if(tmp.address == -1){
            yyerror("print none symbol");
        }else if(0==strncmp(tmp.type, "array", strlen(tmp.type))){
            printf("%c to %c\n", tmp.element_type[0]&0x5f, $1[0]&0x5f);
        }else{
            printf("%c to %c\n", tmp.type[0]&0x5f, $1[0]&0x5f);
        }
    }
    strcpy(now_type, $1); }
;

Statement 
    : DeclarationStmt NEWLINE
    | SimpleStmt NEWLINE
    | Block NEWLINE
    | IfStmt NEWLINE
    | ForStmt NEWLINE
    | PrintStmt NEWLINE
    | NEWLINE
;
SimpleStmt 
    : AssignmentStmt { strcpy(now_type, "none"); }
    | ExpressionStmt { strcpy(now_type, "none"); }
    | IncDecStmt { strcpy(now_type, "none"); }
;

DeclarationStmt 
    :VAR IDENT Type '=' { /*strcpy(now_type, "none");*/ } Expression { 
    if($3[0] != 'A'){
        insert_symbol($2, $3, "-"); 
    }else{
        insert_symbol($2, "array", $3+1); 
    }
    strcpy(now_type, "none");}
    
    | VAR IDENT Type {
    if($3[0] != 'A'){
        insert_symbol($2, $3, "-"); 
    }else{
        insert_symbol($2, "array", $3+1); 
    }
     strcpy(now_type, "none");}
;

AssignmentStmt 
    : left_Stmt assign_op Expression { 
    if( 0 != strcmp(get_type($1), "none") && 0 != strcmp("none", now_type) && 0 != strcmp(get_type($1), now_type)){
        printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n", yylineno, $2, get_type($1), now_type);
    }else if(0 == strcmp($1, "int32")){
        yyerror("cannot assign to int32");
    }
    printf("%s\n", $2);
    /*printf("AssignmentStmt %s %s %s now %s\n", $1,$2,$3, now_type); */
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
    : Expression INC { printf("INC\n"); }
    | Expression DEC { printf("DEC\n"); }
;

Block 
    : '{' { create_symbol(); } StatementList '}' { dump_symbol(cs_idx); }
;

IfStmt 
    : IF Condition Block ELSE IfStmt 
    | IF Condition Block 
    | IF Condition Block ELSE Block 
;
Condition : Expression {
    if( 0 != strcmp("none", get_type($1)) )
        if( 0 == strcmp("int32", get_type($1)) || 0 == strcmp("float32", get_type($1)) ){
            printf("error:%d: non-bool (type %s) used as for condition\n", yylineno+1, get_type($1));
        }
    } 
;

ForStmt 
    : FOR Condition Block 
    | FOR ForClause Block { ; }
;
ForClause 
    : InitStmt ';' Condition ';' PostStmt
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
    }else{
        NODE tmp = lookup_symbol($3, 1);
        if(tmp.address == -1){
            yyerror("print none symbol");
        }else if(0==strncmp(tmp.type, "array", strlen(tmp.type))){
            printf("PRINT %s\n", tmp.element_type);
        }else{
            printf("PRINT %s\n", tmp.type);
        }
    }
    strcpy(now_type, "none");}

    | PRINTLN '(' Expression ')' {
    if(0==strncmp($3, "int32", strlen("int32")) || 0==strncmp($3, "float32", strlen("float32")) 
    || 0==strncmp($3, "bool", strlen("bool")) || 0==strncmp($3, "string", strlen("string")) ){
        printf("PRINTLN %s\n", $3);
    }else{
        NODE tmp = lookup_symbol($3, 1);
        if(tmp.address == -1){
            yyerror("print none symbol");
        }else if(0==strncmp(tmp.type, "array", strlen(tmp.type))){
            printf("PRINTLN %s\n", tmp.element_type);
        }else{
            printf("PRINTLN %s\n", tmp.type);
        }
    }
    strcpy(now_type, "none");}
;

left_Stmt
    : Literal { $$=$1; }
    | IDENT { NODE tmp = lookup_symbol($1, 1); 
        if( tmp.address != -1){
            printf("IDENT (name=%s, address=%d)\n", $1, tmp.address);
            // printf("-------- %s now %s\n", tmp.type, now_type);
            
            strcpy(now_type, tmp.type);
            // marked
            if( 0==strcmp(tmp.type, "array") ){
                strcpy(now_type, "none");
            }
        }else{
            printf("error:%d: undefined: %s\n", yylineno+1, $1);
            // yyerror("not this symbol??"); 
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

    yylineno = 0;
    yyparse();

    dump_symbol(cs_idx);


	printf("Total lines: %d\n", yylineno);
    fclose(yyin);

    if (HAS_ERROR) {
        remove("hw3.j");
    }

    return 0;
}

static void create_symbol() {
    cs_idx++;
    // scope_level[cs_idx] = scope_level[cs_idx-1] + 1;
}

static void insert_symbol(char* name, char* type, char* element_type) {
    NODE tmp = lookup_symbol(name, 0);
    if(tmp.address != -1){
        printf("error:%d: %s redeclared in this block. previous declaration at line %d\n", yylineno, name, tmp.lineno);
        return;
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
