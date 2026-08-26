# SAFIRA — Agente de Desenvolvimento (Compiladores 2026.2)

Você é o assistente técnico de desenvolvimento do **Safira**, um compilador/analisador didático para código C implementado em **Ruby puro**.

---

## 🎯 Objetivo e Regra Eliminatória

O programa deve ser executado a partir de `compiler.rb` recebendo o caminho de um arquivo `.c` como argumento via linha de comando:

```bash
ruby compiler.rb caminho/arquivo.c

O analisador deve processar o código determinística e amigavelmente, exibindo as quatro etapas exigidas pelo barema:  Análise Léxica: Lista ordenada de tokens com seus lexemas/tipos e a Tabela de Símbolos completa.  Análise Sintática: Validação da estrutura gramatical e impressão da Árvore Sintática Abstrata (AST).  Análise Semântica: Identificação de inconsistências com mensagens de erro formatadas.  Defesa / Legibilidade: Código modular, comentado e intuitivo para a apresentação de 5 minutos.  ⚠️ CRITÉRIO ELIMINATÓRIO (NOTA ZERO): Falhas de execução não tratadas (unhandled exceptions / tracebacks feios do Ruby), incapacidade de ler o arquivo de entrada ou ausência de exibição dos elementos avaliados resultam em nota zero imediata.  📁 Estrutura de Arquivos do ProjetoToda a implementação deve respeitar estritamente a seguinte estrutura:PlaintextSafira/
├── src/
│   ├── lexer.rb        # Tokenização, identificação de tokens e Tabela de Símbolos
│   ├── parser.rb       # Recursive Descent Parser, nós sintáticos e AST
│   └── semantic.rb     # Validação de escopo/declaração e tipos
├── compiler.rb         # Ponto de entrada CLI (orquestrador das etapas e impressões)
├── .gitignore
├── CODEOWNERS
├── Gemfile
├── Gemfile.lock
├── README.md
└── AGENT.md

📋 Escopo Gramatical e Semântico EstritoPara evitar escopo excessivo e manter o foco na defesa prática de 5 minutos, foque na gramática simplificada solicitada:  1. Gramática Livre de Contexto (BNF Alvo)BNF<Programa>       ::= (<Declaracao> | <Atribuicao>)*
<Declaracao>     ::= <Tipo> <identificador> ("=" <Expressao>)? ";"
<Tipo>           ::= "int" | "float" | "char" | "double"
<Atribuicao>     ::= <identificador> "=" <Expressao> ";"
<Expressao>      ::= <Termo> (("+" | "-" | "*" | "/") <Termo>)*
<Termo>          ::= <identificador> | <numero> | <string_literal>
2. Validações Semânticas ObrigatóriasChecagem de Variável Não Declarada: Consultar a Tabela de Símbolos antes de permitir o uso de qualquer identificador em atribuições ou expressões.  Formato: [ERRO SEMÂNTICO] Linha X: Variável '<identificador>' utilizada sem declaração prévia.  Compatibilidade de Tipos: Validar se o tipo do valor atribuído é compatível com o tipo declarado na Tabela de Símbolos.  Formato: [ERRO SEMÂNTICO] Linha X: Incompatibilidade de tipos. Não é possível atribuir <TipoB> a '<identificador>' do tipo <TipoA>.  🖥️ Formato Obrigatório de Saída no TerminalA saída de compiler.rb deve ser limpa, estruturada e dividida nas seções abaixo:  Plaintext==================================================
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
(OU caso haja erro:)
✖ [ERRO SEMÂNTICO] Linha 2: Variável 'total' utilizada sem declaração prévia.
  🚫 Diretrizes Críticas de Implementação (O Que NÃO Fazer)❌ NÃO use geradores automáticos de parser como Racc, Lex, Bison ou ANTLR. Todo o analisador deve ser manual (Recursive Descent Parser / Regex) para facilitar a explicação do código na defesa.  ❌ NÃO ignore número de linha e coluna nos tokens; eles são essenciais para apontar erros com precisão[cite: 1].❌ NÃO permita que exceções do Ruby causem crash no terminal (rescue nos pontos certos e imprima mensagens de erro amigáveis)[cite: 1].❌ NÃO adicione dependências pesadas fora da biblioteca padrão do Ruby no core do analisador.
```
