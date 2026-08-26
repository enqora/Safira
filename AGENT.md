# SAFIRA — Agente de Desenvolvimento (Compiladores 2026.2)

Você é o assistente técnico especializado no desenvolvimento do **Safira**, um analisador léxico, sintático e semântico simplificado para código C, implementado em **Ruby puro**[cite: 1].

---

## 🎯 Objetivo Principal & Regra Eliminatória
O programa deve ser executado via linha de comando a partir de `compiler.rb`, recebendo o caminho de um arquivo `.c` como argumento[cite: 1]:
```bash
ruby compiler.rb caminho/arquivo.c
```

Ele deve processar o código-fonte de forma determinística e amigável, apresentando com clareza as quatro etapas avaliadas no barema[cite: 1]:
1. **Análise Léxica:** Lista ordenada de tokens com seus lexemas/tipos e a Tabela de Símbolos completa (com identificadores, palavras reservadas, tipos e ordem de inserção)[cite: 1].
2. **Análise Sintática:** Validação da estrutura gramatical e impressão visual da Árvore Sintática Abstrata (AST) resultante[cite: 1].
3. **Análise Semântica:** Validação de inconsistências semânticas com mensagens de erro formatadas contendo linha e causa[cite: 1].
4. **Defesa / Legibilidade:** Código modular, comentado e intuitivo para a apresentação funcional de 5 minutos[cite: 1].

> ⚠️ **CRITÉRIO ELIMINATÓRIO (NOTA ZERO):** Falhas de execução não tratadas (*unhandled exceptions* / tracebacks do Ruby), incapacidade de ler o arquivo de entrada ou ausência de exibição dos elementos do barema resultam em nota zero imediata[cite: 1].

---

## 📁 Estrutura de Arquivos do Projeto

Mantenha toda a implementação estritamente dentro da estrutura de arquivos existente:

```text
Safira/
├── src/
│   ├── lexer.rb        # Tokenização, emissão de tokens e construção da Tabela de Símbolos
│   ├── parser.rb       # Recursive Descent Parser, definição dos nós e geração da AST
│   └── semantic.rb     # Validação semântica (verificação de tipos e escopo/declaração)
├── compiler.rb         # Ponto de entrada CLI (orquestra leitura do arquivo, etapas e saídas)
├── .gitignore
├── CODEOWNERS
├── Gemfile
├── Gemfile.lock
├── README.md
└── AGENT.md
```

---

## 📋 Escopo Gramatical e Semântico Estrito

Para manter a clareza didática na defesa de 5 minutos e garantir funcionamento robusto, concentre-se estritamente na gramática simplificada solicitada[cite: 1]:

### 1. Gramática Livre de Contexto (BNF Alvo)[cite: 1]
```bnf
<Programa>       ::= (<Declaracao> | <Atribuicao>)*
<Declaracao>     ::= <Tipo> <identificador> ("=" <Expressao>)? ";"
<Tipo>           ::= "int" | "float" | "char" | "double"
<Atribuicao>     ::= <identificador> "=" <Expressao> ";"
<Expressao>      ::= <Termo> (("+" | "-" | "*" | "/") <Termo>)*
<Termo>          ::= <identificador> | <numero> | <string_literal>
```

### 2. Validações Semânticas Obrigatórias[cite: 1]
* **Checagem de Variável Não Declarada:** Consultar a Tabela de Símbolos antes de permitir o uso de qualquer identificador em expressões ou atribuições[cite: 1].
  * *Formato:* `[ERRO SEMÂNTICO] Linha X: Variável '<identificador>' utilizada sem declaração prévia.`[cite: 1]
* **Compatibilidade de Tipos:** Validar se o tipo do valor atribuído é compatível com o tipo declarado na Tabela de Símbolos[cite: 1].
  * *Formato:* `[ERRO SEMÂNTICO] Linha X: Incompatibilidade de tipos. Não é possível atribuir <TipoB> a '<identificador>' do tipo <TipoA>.`[cite: 1]

---

## 🖥️ Formato Obrigatório de Saída no Terminal

A saída de `compiler.rb` deve ser limpa, estruturada e dividida nas seções correspondentes ao barema[cite: 1]:

```text
==================================================
1. ANÁLISE LÉXICA: LISTA DE TOKENS
==================================================
[Linha 1, Col 1]  TIPO: TIPO_DADO     | LEXEMA: 'int'
[Linha 1, Col 5]  TIPO: IDENTIFICADOR | LEXEMA: 'x'
[Linha 1, Col 7]  TIPO: OP_ATRIB      | LEXEMA: '='
[Linha 1, Col 9]  TIPO: NUMERO        | LEXEMA: '5'
[Linha 1, Col 10] TIPO: PONTO_VIRGULA | LEXEMA: ';'

==================================================
2. TABELA DE SÍMBOLOS
==================================================
+---------------+---------+--------+---------------+
| Identificador | Tipo    | Linha  | Ordem Inserção|
+---------------+---------+--------+---------------+
| x             | int     | 1      | 1             |
+---------------+---------+--------+---------------+

==================================================
3. ANÁLISE SINTÁTICA: ÁRVORE SINTÁTICA (AST)
==================================================
Atribuicao
├── ID (x)
├── OP_ATRIB (=)
└── Expressao (+)
    ├── ID (a)
    └── NUM (5)

==================================================
4. ANÁLISE SEMÂNTICA
==================================================
✔ Nenhuma inconsistência semântica encontrada.
(OU caso ocorra erro:)
✖ [ERRO SEMÂNTICO] Linha 2: Variável 'total' utilizada sem declaração prévia.
```

---

## 🚫 Diretrizes Críticas de Implementação (O Que NÃO Fazer)

* ❌ **NÃO** use geradores automáticos de parser como Racc, Lex, Bison ou ANTLR. Todo o analisador léxico e sintático deve ser construído manualmente em Ruby puro para possibilitar a explicação detalhada de cada etapa na defesa[cite: 1].
* ❌ **NÃO** ignore posições de linha e coluna nos tokens, pois elas são essenciais para apontar erros com precisão[cite: 1].
* ❌ **NÃO** permita que exceções do Ruby interrompam o programa abruptamente (`rescue` nos pontos críticos e imprima saídas amigáveis)[cite: 1].
* ❌ **NÃO** adicione dependências de gems externas no fluxo central de execução do compilador.
