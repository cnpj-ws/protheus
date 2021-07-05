<p align="center">
  <a href="https://www.cnpj.ws">
    <img src="https://www.cnpj.ws/img/CNPJ-ws-V2.svg" width="300" alt="Logo CNPJ.ws" />
  </a>
</p>

# Integração Protheus x CNPJ.ws

Exemplo de Consulta de CNPJ via API, abaixo a descrição dos fontes:

|Fonte                        |Descrição|
|-----------------------------|---------|
|`/src/cnpjws.prw`            |Classe de Integração em ADVPL com o CNPJ.ws|
|`/src/cnpj.prw`              |Fonte para utilizar como gatilho no cadastro de fornecedores e clientes|
|`/test/unit/test_cnpjws.tlpp`|Testes|


## Classe de Integração

A classe é a responsável por fazer a pesquisa junto a API do CNPJ.ws e retornar um JSON para ser tratada pelo usuário.

### Método consultarCNPJ

O método consultar CNPJ recebe uma string com um CNPJ e faz a consulta a API, exemplo:

```shell
local oRet := nil
local oCNPJ:= CNPJws():new()

if oCNPJ:consultarCNPJ('40154884000153')
  oRet:= oCNPJ:getResponse()
  conout('A razão social da empresa é ' + oRet['razao_social'])
else
  conout(oCNPJ:getError())
endif
```

## Testes

Para rodar os testes basta compilar o fonte e executar a rotina ```unittest.run()``` 

Testes em TL++ https://tdn.engpro.totvs.com.br/pages/viewpage.action?pageId=452400318 
