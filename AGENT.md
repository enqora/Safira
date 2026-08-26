```markdown
# SAFIRA — Agente de Desenvolvimento (Compiladores 2026.2)

Você é o assistente técnico especializado no desenvolvimento do **Safira**, um compilador/analisador léxico, sintático e semântico simplificado para código C, implementado em **Ruby puro**.

O diferencial central do **Safira** é ser um compilador **elegante, idiomático e com apresentação visual de alto padrão no terminal (CLI UI)**, unindo rigor acadêmico com excelência de software design.

---

## 🎯 Objetivo Principal & Regra Eliminatória

O programa deve ser executado a partir de `compiler.rb`, recebendo como argumento o caminho de um arquivo de código-fonte (`.c` ou `.java`):
```bash
ruby compiler.rb caminho/arquivo.c

```

Ele deve processar o código de forma determinística, dividindo a execução e a visualização nas quatro etapas do barema:

1. **Análise Léxica:** Emissão da lista ordenada de tokens e construção visual da Tabela de Símbolos completa (identificadores, palavras reservadas, tipos inferidos/declarados e ordem cronológica de inserção).
2. **Análise Sintática:** Validação gramatical via analisador descendente recursivo (*Recursive Descent Parser*) e renderização visual da Árvore Sintática Abstrata (AST) com caracteres Unicode hierárquicos.
3. **Análise Semântica:** Validação das **duas opções do barema** (Compatibilidade de Tipos e Variável Não Declarada) com diagnósticos contextuais no estilo *Clang/Rust*.
4. **Defesa / Arquitetura:** Código limpo, idiomático, desacoplado e pronto para a explicação funcional da equipe durante os 5 minutos de apresentação.

> ⚠️ **CRITÉRIO ELIMINATÓRIO (NOTA ZERO):** Falhas não tratadas (*unhandled exceptions* / tracebacks do Ruby), falha na leitura do arquivo ou ausência de exibição clara dos elementos do barema resultam em nota 0,0.

---

## 💎 Pilares de Elegância do Safira

Para garantir um projeto diferenciado, a implementação deve seguir estes três pilares:

### 1. Visual CLI & Experiência de Terminal de Alto Padrão

* **Tabelas ASCII Estilizadas:** A Tabela de Símbolos e os Tokens devem ser impressos com bordas refinadas (`+---+` ou caracteres Unicode de caixa) e alinhamento tipográfico uniforme.
* **Árvore Sintática (AST) Gráfica em Unicode:** Em vez de JSON ou listas planas, desenhar a hierarquia em árvore usando ramificações legíveis (`├──`, `└──`, `│   `).
* **Diagnósticos com Apontamento de Linha e Coluna:** Mensagens de erro semântico e sintático devem exibir o trecho de código afetado com um cursor/seta indicativa (`^^^^^^`), facilitando a compreensão visual imediata.
* **Paleta de Cores ANSI Discreta:** Uso consciente de cores no terminal (ex.: tons de verde para validações bem-sucedidas, amarelo para tokens/nós e vermelho para erros contextuais).

### 2. Ruby Moderno e Idiomático

* **Estruturas de Dados Limpas:** Uso de `Data.define` ou `Struct` imutáveis para `Token`, `SymbolEntry` e nós da AST (`VarDeclNode`, `AssignNode`, `BinaryOpNode`, etc.).
* **Pattern Matching (`case ... in`):** Priorizar casamento de padrões para inspecionar nós da AST no analisador semântico e no renderizador da árvore, mantendo o código conciso e legível.
* **Separação Rígida de Camadas:** As classes `Lexer`, `Parser` e `SemanticAnalyzer` não devem realizar `puts` internamente. Elas apenas processam dados e retornam estruturas/erros; a formatação visual e orquestração ficam a cargo exclusivo de `compiler.rb` ou de módulos renderizadores dedicados.

### 3. Modos de Execução e Demonstração

* O `compiler.rb` deve suportar a execução completa por padrão, mas aceitar flags opcionais (ex.: `--tokens`, `--symbols`, `--ast`, `--semantic`) para facilitar a demonstração isolada de cada etapa caso a banca examinadora solicite.

---

## 📁 Estrutura de Arquivos do Projeto

Toda a implementação deve respeitar estritamente a estrutura existente no repositório:

```text
Safira/
├── src/
│   ├── lexer.rb        # Tokenização, regex rules, controle de linha/coluna e Tabela de Símbolos
│   ├── parser.rb       # Recursive Descent Parser, nós da AST e checagem de GLC
│   └── semantic.rb     # Análise semântica (Opção 1: Tipos | Opção 2: Declaração/Escopo)
├── samples/            # Arquivos .c de exemplo para os testes e a apresentação
│   ├── valid.c         # Fluxo perfeito com declaração e expressões aritméticas
│   ├── err_type.c      # Demonstração de incompatibilidade de tipos
│   └── err_scope.c     # Demonstração de variável não declarada
├── compiler.rb         # Ponto de entrada CLI, orquestração e renderizador visual
├── .gitignore
├── CODEOWNERS
├── Gemfile
├── Gemfile.lock
├── README.md
└── AGENT.md

```

---

## 📋 Escopo Gramatical e Semântico

### 1. Gramática Livre de Contexto (BNF Alvo)

```bnf
<Programa>       ::= (<Declaracao> | <Atribuicao>)*
<Declaracao>     ::= <Tipo> <identificador> ("=" <Expressao>)? ";"
<Tipo>           ::= "int" | "float" | "char" | "double"
<Atribuicao>     ::= <identificador> "=" <Expressao> ";"
<Expressao>      ::= <Termo> (("+" | "-" | "*" | "/") <Termo>)*
<Termo>          ::= <identificador> | <numero> | <string_literal>

```

### 2. Validações Semânticas (Ambas as opções implementadas)

* **Opção 1: Checagem de Compatibilidade de Tipos:**
* O sistema deve inferir o tipo da expressão à direita da atribuição e validar a compatibilidade com o tipo declarado na Tabela de Símbolos.


* **Opção 2: Checagem de Variável Não Declarada:**
* Toda variável usada em atribuições ou expressões deve ser previamente validada contra a Tabela de Símbolos.



---

## 🖥️ Layout Padrão de Saída no Terminal

A saída de `compiler.rb` deve manter uma identidade visual uniforme, limpa e bem delimitada:

```text
================================================================================
  SAFIRA COMPILER — Análise de Código C
  Arquivo: samples/valid.c
================================================================================

[1] ANÁLISE LÉXICA: LISTA DE TOKENS
--------------------------------------------------------------------------------
 [Linha  1, Col  1]  TIPO: TIPO_DADO        | LEXEMA: 'int'
 [Linha  1, Col  5]  TIPO: IDENTIFICADOR    | LEXEMA: 'x'
 [Linha  1, Col  7]  TIPO: OP_ATRIB         | LEXEMA: '='
 [Linha  1, Col  9]  TIPO: NUMERO           | LEXEMA: '5'
 [Linha  1, Col 10]  TIPO: PONTO_VIRGULA    | LEXEMA: ';'

[2] TABELA DE SÍMBOLOS
--------------------------------------------------------------------------------
 +---------------+---------+--------+---------------+
 | Identificador | Tipo    | Linha  | Ordem Inserção|
 +---------------+---------+--------+---------------+
 | x             | int     | 1      | 1             |
 | total         | float   | 2      | 2             |
 +---------------+---------+--------+---------------+

[3] ANÁLISE SINTÁTICA: ÁRVORE SINTÁTICA (AST)
--------------------------------------------------------------------------------
 Atribuicao
 ├── ID (x)
 ├── OP_ATRIB (=)
 └── Expressao (+)
     ├── ID (a)
     └── NUM (5)

[4] ANÁLISE SEMÂNTICA
--------------------------------------------------------------------------------
 ✔ Nenhuma inconsistência semântica encontrada.

 (OU em caso de erro semântico / diagnóstico elegante:)
 ✖ [ERRO SEMÂNTICO] Incompatibilidade de tipos na linha 3:
     3 | int resultado = "texto";
       |                 ^^^^^^^ Não é possível atribuir String a 'resultado' (int).

 ✖ [ERRO SEMÂNTICO] Variável não declarada na linha 5:
     5 | total = 10;
       | ^^^^^ Variável 'total' utilizada sem declaração prévia.
================================================================================

```

---

## 🚫 Diretrizes Críticas de Implementação

* ❌ **NÃO** utilize geradores automáticos de código (Racc, Lex, Bison, ANTLR). Todo o pipeline deve ser escrito em Ruby puro.
* ❌ **NÃO** dependa de gems externas para formatação ou parsing. Garanta portabilidade total para execução em qualquer ambiente padrão com Ruby.
* ❌ **NÃO** deixe chamadas de I/O (`puts`, `print`) dispersas dentro do core do compilador (`lexer.rb`, `parser.rb`, `semantic.rb`).
* ❌ **NÃO** permita que exceções quebrem a execução abruptamente com tracebacks. Capture erros e exiba diagnósticos elegantes.

```

```
