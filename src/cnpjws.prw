#include 'totvs.ch'
#include 'protheus.ch'

/*/{Protheus.doc} CNPJws
Classe de integraçao com a API do CNPJ.ws.
@type class
@version 1.0 
@author Carlos Tirabassi
@since 07/06/2021
/*/
class CNPJws

	data lVerb	  as Logical
	data cURL     as String
	data cToken   as String
	data cErro    as String
	data cRet     as String
	data oRet     as String
	data aHeaders as Array
	data lRet     as Logical

	method new() CONSTRUCTOR
	method consoleLog(cMsg,lErro)
	method setError(oRest)

	method consultarCNPJ(cCNPJ)
	method getResponse()
	method getError()

endClass

/*/{Protheus.doc} CNPJws::new
Instância a classe
@type method
@version 1.0  
@author Carlos Tirabassi
@since 07/06/2021
@param lTest, logical, Indica se esta sendo chamado pela rotina de testes
@return object, Objeto CNPJ.ws
/*/
method new(lTest) class CNPJws

	default lTest:= .f.

	::cToken  := if(lTest, '', superGetMV('CN_TOKEN',.f.,''))
	::cURL    := if(empty(::cToken),'https://publica.cnpj.ws','https://comercial.cnpj.ws')
	::lVerb   := if(lTest, .t., superGetMV('CN_VERBO',.f.,.t.)) //Indica se ira imprimir todas as msgs no console
	::cErro   := ''
	::cRet    := ''
	::oRet    := nil
	::lRet    := .t.
	::aHeaders:= {"Content-Type: application/json; charset=utf-8"}

	if !empty(::cToken)
		aAdd(::aHeaders,'x_api_token: ' + allTrim(::cToken))
	endif

	::consoleLog('Classe instanciada com sucesso!')

return Self

/*/{Protheus.doc} CNPJws::consultarCNPJ
Consultar CNPJ
@type method
@author Carlos Tirabassi
@since 07/06/2021
@param cCNPJ, character, Número do CNPJ
@return logical, Indica se conseguiu fazer a consulta
/*/
method consultarCNPJ(cCNPJ) class CNPJws
	local oRest	:= FWRest():New(::cURL)
	local cPath := '/cnpj/'

	::cRet := ''
	::oRet := nil
	::lRet := .t.
	::cErro:= ''

	cPath+= allTrim(cCNPJ)

	oRest:setPath(cPath)

	if oRest:Get(::aHeaders)
		if !empty(oRest:GetResult())
			::cRet:= FWNoAccent(DecodeUtf8(oRest:GetResult()))

			if empty(::cRet)
				::cRet:= FWNoAccent(oRest:GetResult())
			endif

			::cRet:= strTran(::cRet,'\/','/')
			::cRet:= strtran(::cRet,":null",': " "')
			::cRet:= strtran(::cRet,'"self"','"_self"')

			::oRet:= JsonObject():new()
			::oRet:fromJson(::cRet)

			::lRet := .t.
			::cErro:= ''
		else
			::oRet := nil
			::cErro:= ''
			::lRet := .t.
		endif
		::consoleLog('Sucesso! ' + cPath)
	else
		::setError(oRest,cPath)
	endif

	FreeObj(oRest)

return ::lRet

/*/{Protheus.doc} CNPJws::setError
Padronizacao de erros
@type method
@author Carlos
@since 07/06/2021
@param oRest, object, Objeto FWRest
@param cPath, character, Path
/*/
method setError(oRest,cPath) class CNPJws
	local cLog		:= ''
	local cAux  	:= ''
	local cStatus	:= ''

	default cPath:= ''

	::oRet := nil

	::cRet:= oRest:GetResult()

	if valType(::cRet) <> 'C'
		::cRet:= ''
	endif

	if !empty(::cRet)
		::cRet:= FWNoAccent(DecodeUtf8(::cRet))

		if empty(::cRet)
			::cRet:= FWNoAccent(oRest:GetResult())
		endif
	endif

	cAux:= FWNoAccent(DecodeUtf8(oRest:GetLastError()))

	if empty(cAux)
		cAux:= FWNoAccent(oRest:GetLastError())
	endif

	cStatus:= oRest:GetHTTPCode()

	cLog+= 'Host: ' + ::cURL + CRLF
	cLog+= 'Operacao: ' + ProcName(1) + ' ' + cPath + CRLF
	cLog+= 'HTTP Code: ' + cStatus + CRLF
	cLog+= 'Erro: ' + cAux + CRLF
	cLog+= 'Resultado: ' + ::cRet + CRLF

	::consoleLog(cLog,.T.)

return

/*/{Protheus.doc} CNPJws::consoleLog
Mensagens no console
@type method
@author Carlos Tirabassi
@since 07/06/2021
@param cMsg, character, Mensagem
@param lErro, logical, Indica se é um erro, default é .f.
/*/
method consoleLog(cMsg,lErro) class CNPJws
	local cLog:= ''

	default cMsg := ''
	default lErro:= .f.

	if ::lVerb .or. lErro
		cLog:= '[' + dtoc(date()) + ']'
		cLog+= '[' + time() + ']'
		cLog+= '[' + ProcName(1) + ']'
		cLog+= '[' + cValToChar(ProcLine(1)) + ']'
		cLog+= '['+allTrim(cMsg)+']'

		if lErro
			::cErro:= cLog
			::lRet := .f.
		endif

		if ::lVerb .or. lErro
			conout(cLog)
		endif

	endif
return

/*/{Protheus.doc} CNPJws::getResponse
Retorna a resposta da consulta
@type method 
@author Carlos Tirabassi
@since 07/06/2021
@return object, JSON de retorno
/*/
method getResponse() class CNPJws
return ::oRet

/*/{Protheus.doc} CNPJws::getError
Retorna o erro da consulta
@type method
@author Carlos Tirabassi
@since 07/06/2021
@return character, Mensagem de erro
/*/
method getError() class CNPJws
return ::cErro

user function tstCNPJ()
	local oCNPJ:= nil
	local oJSON:= nil

	RpcSetType(3)
	if !RpcSetEnv('99','01')
		return
	endif

	//Instancia a classe
	oCNPJ:= CNPJws():new()

	if oCNPJ:consultarCNPJ('40154884000153')
		oJSON:= oCNPJ:getResponse()
	endif

	RPCClearEnv()

return
