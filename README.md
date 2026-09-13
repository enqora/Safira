# 💎 Safira

Um compilador didático escrito em **Ruby puro**, que analisa código-fonte em C
e mostra cada etapa do processo no terminal.

Projeto da disciplina de **Compiladores (2026.2)**.

O Safira faz as três análises clássicas de um compilador — **léxica**,
**sintática** e **semântica** — e apresenta o resultado de cada uma com tabelas,
árvores e diagnósticos coloridos, em vez de despejar texto cru.

---

## Requisitos

- **Ruby 3.2 ou superior** (o projeto usa `Data.define`)
- Nenhuma gem externa é necessária para rodar

```bash
ruby -v
```

As gems do `Gemfile` (`rspec`, `rubocop`, `ruby-lsp`) são só para desenvolvimento.

---

## Como usar

> 🚧 **Em construção.** O ponto de entrada (`compiler.rb`) ainda não foi
> implementado. Por enquanto, use os testes para ver os módulos prontos
> funcionando (seção [Testes](#testes)).

Quando estiver completo, o uso será:

```bash
ruby compiler.rb samples/valid.c
```

E flags opcionais para ver uma etapa isolada:

```bash
ruby compiler.rb samples/valid.c --tokens     # só a lista de tokens
ruby compiler.rb samples/valid.c --symbols    # só a tabela de símbolos
ruby compiler.rb samples/valid.c --ast        # só a árvore sintática
ruby compiler.rb samples/valid.c --semantic   # só a análise semântica
```

---

## As quatro etapas

### 1. Análise Léxica — *quebrar o texto em pedaços*

Lê o código caractere a caractere e o transforma em **tokens**, cada um com tipo,
lexema, linha e coluna. Ignora espaços e comentários.

```
int x = 5;
```

vira

```
 [Linha  1, Col  1]  TIPO: TIPO_DADO        | LEXEMA: 'int'
 [Linha  1, Col  5]  TIPO: IDENTIFICADOR    | LEXEMA: 'x'
 [Linha  1, Col  7]  TIPO: OP_ATRIB         | LEXEMA: '='
 [Linha  1, Col  9]  TIPO: NUMERO           | LEXEMA: '5'
 [Linha  1, Col 10]  TIPO: PONTO_VIRGULA    | LEXEMA: ';'
```

### 2. Tabela de Símbolos — *quem é quem*

Registra cada identificador encontrado, sem repetir, na ordem em que aparecem.

```
 +---------------+---------+--------+----------------+
 | Identificador | Tipo    | Linha  | Ordem Inserção |
 +---------------+---------+--------+----------------+
 | x             | int     | 1      | 1              |
 | total         | float   | 2      | 2              |
 +---------------+---------+--------+----------------+
```

### 3. Análise Sintática — *o código faz sentido?*

Verifica se os tokens seguem as regras da gramática e monta a **AST** (árvore
sintática abstrata), que representa a estrutura do programa:

```
 Atribuicao
 ├── ID (x)
 ├── OP_ATRIB (=)
 └── Expressao (+)
     ├── ID (a)
     └── NUM (5)
```

### 4. Análise Semântica — *o código faz sentido de verdade?*

A sintaxe pode estar certa e o código ainda ser inválido. Duas checagens:

- **Compatibilidade de tipos** — não dá para guardar texto numa variável `int`
- **Variável não declarada** — não dá para usar o que nunca foi criado

```
 ✖ [ERRO SEMÂNTICO] Incompatibilidade de tipos na linha 3:
     3 | int resultado = "texto";
       |                 ^^^^^^^ Não é possível atribuir String a 'resultado' (int).
```

---

## A gramática

O Safira reconhece este subconjunto de C:

```bnf
<Programa>    ::= (<Declaracao> | <Atribuicao>)*
<Declaracao>  ::= <Tipo> <identificador> ("=" <Expressao>)? ";"
<Tipo>        ::= "int" | "float" | "char" | "double"
<Atribuicao>  ::= <identificador> "=" <Expressao> ";"
<Expressao>   ::= <Termo> (("+" | "-" | "*" | "/") <Termo>)*
<Termo>       ::= <identificador> | <numero> | <string_literal>
```

---

## Estrutura do projeto

```
Safira/
├── src/
│   ├── lexer.rb        # análise léxica + tabela de símbolos
│   ├── parser.rb       # análise sintática + nós da AST
│   └── semantic.rb     # análise semântica
├── samples/            # arquivos .c de exemplo
├── compiler.rb         # ponto de entrada e formatação visual
├── test_lexer.rb       # testes do lexer
└── test_cursor.rb      # testes do cursor do parser
```

**Regra de arquitetura:** os módulos em `src/` nunca imprimem nada. Eles apenas
processam dados e devolvem estruturas ou listas de erro. Toda a formatação
visual fica no `compiler.rb`. Isso mantém o núcleo testável e a apresentação
trocável.

---

## Status

| Etapa | Situação |
|---|---|
| Análise léxica | ✅ Completa — tokens, tabela de símbolos, comentários, erros léxicos |
| Nós da AST | ✅ Completos |
| Cursor do parser | ✅ Completo — `peek`, `advance`, `check?`, `at_end?` |
| Gramática do parser | 🚧 Em construção |
| Análise semântica | ⬜ Não iniciada |
| CLI (`compiler.rb`) | ⬜ Não iniciada |
| Arquivos de exemplo | ⬜ Não criados |

---

## Testes

Não é preciso instalar nada. Rode direto da raiz do projeto:

```bash
ruby test_lexer.rb
```

```bash
ruby test_cursor.rb
```

Cada teste imprime uma lista de verificações. Verde é bom.

---

## Tratamento de erros

O Safira **nunca quebra com traceback**. Erros léxicos, sintáticos e semânticos
são acumulados em listas e exibidos como diagnósticos legíveis ao final.

Isso é proposital: um arquivo com três erros mostra os três de uma vez, em vez
de parar no primeiro.

---

## Autores

- **Leonardo da Silva Badauê** ([@enqora](https://github.com/enqora))
- **Micael Melo** ([@MeloMicael](https://github.com/MeloMicael))
