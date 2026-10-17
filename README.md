# 💎 Safira

Um compilador didático escrito em **Ruby puro**, que analisa código-fonte em C
e mostra cada etapa do processo no terminal.

Projeto da disciplina de **Compiladores (2026.2)**.

O Safira faz as três análises clássicas de um compilador — **léxica**,
**sintática** e **semântica** — e apresenta o resultado de cada uma com tabelas,
árvores e diagnósticos coloridos bem bonitos :)

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

Execute direto na raiz do projeto passando um arquivo `.c`:

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
│   ├── lexer.rb            # análise léxica + tabela de símbolos
│   ├── parser.rb           # análise sintática + nós da AST
│   └── semantic.rb         # análise semântica
├── samples/                # arquivos .c de exemplo (valid.c, err_type.c, err_scope.c)
├── tests/                  # suítes de testes automatizados
│   ├── test_lexer.rb
│   ├── test_cursor.rb
│   ├── test_parser.rb
│   ├── test_semantic.rb
│   └── test_compiler.rb
└── compiler.rb             # ponto de entrada CLI e formatação visual
```

---

## Autores

- **Leonardo da Silva Badauê** ([@enqora](https://github.com/enqora))
- **Micael Melo** ([@MeloMicael](https://github.com/MeloMicael))
