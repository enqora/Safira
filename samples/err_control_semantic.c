/* Demonstração de erros semânticos dentro de if, while e for */
int main() {
    int limite = 10;
    float media = 7.5;

    while (contador < limite) {
        limite = limite - 1;
    }

    for (int i = 0; i < limite; i++) {
        int dobro = i * 2;
    }
    limite = dobro;

    if ("verdadeiro") {
        media = 1;
    }

    return media;
}
