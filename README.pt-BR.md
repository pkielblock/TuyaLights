# Luzes

[English](README.md) · Português (Brasil)

Um app de iPhone que controla lâmpadas Bluetooth Tuya (vendidas com as marcas Smart Life / Tuya) sem a nuvem da Tuya, sem conta e sem o app Smart Life.

Muitas lâmpadas Bluetooth Tuya baratas não aceitam uma conexão Bluetooth normal. O Smart Life as controla com o **Tuya Beacon**: o celular transmite quadros curtos, todas as lâmpadas próximas escutam, e a lâmpada indicada no quadro executa o comando. As lâmpadas nunca respondem. O Luzes grava esses quadros uma vez e depois os envia sozinho, então funciona offline e sem conta.

## Recursos

- Ligar e desligar cada lâmpada, além de Ligar todas e Desligar todas
- Quente, branca e fria, mais oito cores: vermelho, laranja, amarelo, verde, ciano, azul, roxo e rosa
- **Grupos:** controle várias lâmpadas como uma só, com liga/desliga, brancos e cores
- **Cenas:** um toque coloca cada lâmpada no seu próprio estado, por exemplo duas quentes, uma vermelha e duas desligadas; lâmpadas fora da cena não são alteradas
- **Modo de organização:** toque em Editar para arrastar os blocos na sua ordem, renomear lâmpadas e editar ou apagar cenas e grupos
- Inglês e português (Brasil), trocados em Ajustes sem reiniciar; inglês é o padrão
- Visual preto e discreto: cartões neutros, um único azul de destaque para o que está ligado ou selecionado, botões nativos de Liquid Glass no iOS 26
- Sem acesso à rede, sem conta e sem analytics; tudo fica no celular

Brilho não é suportado, porque um comando só funciona se tiver sido gravado antes (veja [Limitações](#limitações)).

## Como funciona

Cada comando é um quadro de 26 bytes, transmitido como 13 UUIDs de serviço Bluetooth de 16 bits (cada UUID em little-endian):

| Bytes | Campo |
|---|---|
| 0 | `0x0b` |
| 1–4 | Endereço da lâmpada (node) |
| 5–6 | Contador do quadro, big-endian |
| 7 | Tipo de quadro: `05` é um comando, `01` é uma consulta de estado |
| 8–24 | Payload criptografado, 17 bytes |
| 25 | CRC-8, polinômio `0x07`, sobre os bytes 1–24, a partir de uma semente |

O que se descobriu gravando o Smart Life:

- **O payload é fixo por lâmpada e por comando.** Ele não depende do contador, então um "vermelho" gravado para uma lâmpada pode ser enviado várias vezes. Os payloads mudam entre lâmpadas, então cada lâmpada precisa da sua própria gravação.
- **O contador precisa subir.** A lâmpada ignora qualquer quadro cujo contador não seja maior que o último aceito. Esse último valor é compartilhado por todo o grupo do Smart Life, então um quadro enviado a uma lâmpada sobe o limite das outras. O Luzes mantém um contador de 16 bits por grupo e o salva.
- **A semente do CRC muda por grupo,** então a semente também indica a qual grupo a lâmpada pertence.
- **Os tons de branco vêm depois de um comando de modo branco.** O Smart Life envia esse comando primeiro, e o Luzes faz o mesmo, a não ser que a lâmpada já esteja em um branco.

O iOS só transmite um anúncio por vez, então o Luzes enfileira os quadros e envia cada um por 0,6 s. Deixar cinco lâmpadas em quente leva alguns segundos.

## Configuração

Você precisa de um Mac com Xcode, um iPhone e lâmpadas já pareadas no Smart Life.

### 1. Grave suas lâmpadas

Deixe o celular perto do Mac, inicie o gravador e use o Smart Life para tocar em todos os comandos de cada lâmpada: ligar, desligar, quente, branca, fria e cada cor.

```sh
swift tools/record.swift 300
```

Na primeira vez, o macOS pede permissão de Bluetooth para o terminal. O gravador mostra uma linha para cada quadro novo:

```
node      counter type payload                            crc
0a1b0001    118b    05    33c1d2e3f4a5b6c7d8e9fa0b1c2d3e4f50 7c
```

Faça uma lâmpada por vez, numa ordem fixa, e anote qual payload veio de qual botão. Dentro de um grupo, os dois primeiros dígitos hex de um payload são iguais em todas as lâmpadas para um mesmo comando (por exemplo `33…` é ligar, `d6…` é desligar), o que ajuda a separar os comandos. Ao escolher um tom de branco, o Smart Life envia primeiro o payload de modo branco e depois o tom.

### 2. Escreva `TuyaLights/Lamps.json`

Copie `Lamps.example.json` para `TuyaLights/Lamps.json` e preencha:

```json
{
  "lamps": [
    {
      "name": "Bedside lamp",
      "node": "0a1b0001",
      "seed": "18",
      "counter": "1300",
      "commands": {
        "on": "…", "off": "…", "white": "…",
        "warm": "…", "neutral": "…", "cool": "…",
        "red": "…", "orange": "…", "yellow": "…", "green": "…",
        "cyan": "…", "blue": "…", "purple": "…", "pink": "…"
      }
    }
  ]
}
```

- `node`: o endereço de 4 bytes mostrado pelo gravador
- `seed`: a semente do CRC do grupo da lâmpada, em hex. Para achá-la, pegue um quadro gravado e teste as 256 sementes sobre os bytes 1–24 até o CRC bater com o último byte. Todas as lâmpadas de um grupo usam a mesma semente.
- `counter`: onde começar a contar, em hex. Use um valor maior que qualquer contador que o gravador mostrou para aquele grupo.
- `commands`: os payloads de 17 bytes em hex. `white` é o comando de modo branco, e `neutral` é o tom branco simples.

`Lamps.json` está no `.gitignore`. Quem tiver esse arquivo pode controlar suas lâmpadas dentro do alcance do Bluetooth, então não o publique.

Guarde um backup privado desse arquivo. Você também pode mantê-lo fora do checkout e
criar um symlink em `TuyaLights/Lamps.json`. O build confere se o arquivo existe e
bate com o recurso empacotado, para nunca gerar um app sem lâmpadas sem avisar.

### 3. Compile

Abra `TuyaLights.xcodeproj`, defina seu próprio time de assinatura e bundle identifier e rode o app no seu iPhone. A transmissão Bluetooth não funciona no Simulador.

Para um IPA assinado para desenvolvimento, o perfil de provisionamento embutido precisa
incluir o seu iPhone e não pode ter expirado. Para instalar sem assinar de novo, descompacte
o IPA e arraste `Payload/TuyaLights.app` para a janela Devices and Simulators do Xcode com
o iPhone conectado. Contas gratuitas permitem até três apps instalados, e os builds
expiram em sete dias; compile de novo com o Xcode para renovar.

Mantenha o bundle identifier e o time de assinatura ao atualizar, e instale por cima do
app existente. Apagar o Luzes remove os contadores, cenas e grupos salvos.

O erro `7252` do Sideloadly (certificado não encontrado no time) é da solicitação de
assinatura dele à Apple; mudar o bundle identifier do IPA não resolve essa solicitação.
Um build já assinado pode ser instalado direto pelo Xcode.

## Limitações

- **Só comandos gravados funcionam.** Os payloads são criptografados, então novas cores ou níveis de brilho não podem ser gerados sem as chaves das lâmpadas e o esquema de criptografia. Os dois ainda são desconhecidos.
- **As lâmpadas nunca respondem.** O Luzes mostra o último comando enviado, então mudanças feitas no Smart Life ou no interruptor não aparecem no app.
- **O Smart Life pode ser ignorado por um tempo depois de usar o Luzes,** porque o contador dele agora está abaixo do que o Luzes usa. O Luzes sempre avança o próprio contador.
- **Remover uma lâmpada do Smart Life, ou resetá-la, faz um novo pareamento.** Depois disso, os comandos gravados deixam de funcionar.
- O Luzes foi testado com um conjunto de lâmpadas Smart Life RGB+CCT. Outros dispositivos Tuya Beacon podem usar quadros diferentes.

## Estrutura do projeto

```
TuyaLights/
  Beacon.swift        Carrega as lâmpadas, monta quadros, fila de transmissão
  ContentView.swift   Início: cenas, grupos, lâmpadas, modo de organização
  LampView.swift      Controles de uma lâmpada ou de um grupo
  Scenes.swift        Cenas e o editor de cenas
  Groups.swift        Grupos e o editor de grupos
  LampList.swift      Nomes e ordem das lâmpadas
  SettingsView.swift  Idioma
  Language.swift      Textos em inglês e português
  Style.swift         Fundo preto, cartões, destaque e botões de vidro
  pt-BR.lproj/        Nome do app e aviso de Bluetooth em português
tools/record.swift    Gravador de quadros do Smart Life para Mac
Lamps.example.json    Modelo para TuyaLights/Lamps.json
```

## Aviso

Este projeto não é afiliado nem endossado pela Tuya. Ele só reenvia quadros gravados do seu próprio celular, para controlar lâmpadas que são suas.

## Licença

[MIT](LICENSE)
