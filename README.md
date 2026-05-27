# Estudo SQL — Olist Brazilian E-Commerce

Projeto de estudo de SQL utilizando o dataset público da Olist (e-commerce brasileiro).
O objetivo é praticar consultas, análises e modelagem de dados relacionais com dados reais.

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — licença CC BY-NC-SA 4.0.

Contém ~100k pedidos realizados entre 2016 e 2018, com informações de clientes, produtos, vendedores, pagamentos e avaliações.

### Tabelas

| Tabela | Registros | Descrição |
|--------|----------:|-----------|
| customers | 99.441 | Clientes e localização |
| orders | 99.441 | Pedidos e status |
| order_items | 112.650 | Itens por pedido |
| order_payments | 103.886 | Formas de pagamento |
| order_reviews | 99.224 | Avaliações dos pedidos |
| products | 32.951 | Produtos e dimensões |
| sellers | 3.095 | Vendedores |
| geolocation | 1.000.163 | Coordenadas por CEP |
| product_category_name_translation | 71 | Categorias PT → EN |

## Pré-requisitos

- Python 3.8+
- PostgreSQL acessível (local ou via Docker)
- Conta no [Kaggle](https://www.kaggle.com) com API token

## Configuração

1. Instale as dependências:
   ```bash
   pip install -r requirements.txt
   ```

2. Configure as variáveis de ambiente (copie `.env.example` para `.env` e preencha):
   ```bash
   cp .env.example .env
   ```

   | Variável | Descrição |
   |----------|-----------|
   | `KAGGLE_USERNAME` | Seu usuário do Kaggle |
   | `KAGGLE_KEY` | Token da API do Kaggle |
   | `DB_HOST` | Host do PostgreSQL |
   | `DB_PORT` | Porta (padrão: 5432) |
   | `DB_NAME` | Nome do banco |
   | `DB_USER` | Usuário do banco |
   | `DB_PASSWORD` | Senha do banco |

   > O token Kaggle pode ser gerado em: **kaggle.com/settings → API → Create New Token**

3. Exporte as variáveis e execute o script:
   ```bash
   export $(cat .env | xargs)
   python load_olist.py
   ```

   O script irá:
   - Baixar o dataset diretamente do Kaggle
   - Criar todas as tabelas no banco
   - Carregar os dados via `COPY`

## Ambiente com Docker + Vagrant (opcional)

O repositório inclui um `docker-compose.yml` com PostgreSQL 17 e pgAdmin 4, e um `Vagrantfile` para subir tudo em uma VM isolada com libvirt/KVM.

```bash
# Subir a VM
vagrant up

# Acessar
vagrant ssh

# pgAdmin disponível em http://192.168.56.11:5050
```

## Estrutura do projeto

```
estudo-sql/
├── load_olist.py        # Script de download e carga
├── requirements.txt     # Dependências Python
├── docker-compose.yml   # PostgreSQL + pgAdmin
├── Vagrantfile          # VM de desenvolvimento
├── .env.example         # Template de variáveis
└── README.md
```
# olist-sql-queries
