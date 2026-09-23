#include 'totvs.ch'
#include 'fwmvcdef.ch'

/*/{Protheus.doc} getCNPJ
Gatilho para o cadastro de cliente e fornecedor. Exemplo de cadastro do gatilho:
Campo				: A1_CGC ou A2_CGC
Cnt. Dominio: A1_NOME ou A2_NOME
Tipo				: 1
Regra				: u_getCNPJ('SA1',M->A1_CGC) ou u_getCNPJ('SA2',M->A2_CGC)
Posiciona		: 2
Condicao		: Len(AllTrim(M->A1_CGC)) == 14 ou Len(AllTrim(M->A2_CGC)) == 14

Funciona tanto com o cadastro em MVC (MATA020 / CRMA980) quanto com o cadastro
tradicional (MATA030 sem MVC), preenchendo os campos pelo model ativo ou pelas
variaveis de memoria.
@type function
@version 1.1
@author Carlos Tirabassi
@since 08/06/2021
@param cTab, character, Passar a tabela (SA1 ou SA2)
@param cCNPJ, character, CNPJ
@return character, razão social
/*/
user function getCNPJ(cTab,cCNPJ)
	local aArea   := {CC3->(getArea()), CCH->(getArea()), SYA->(getArea()), getArea()}
	local cRet    := ''
	local cCpoNome:= ''
	local cMaster := ''
	local oModel  := nil

	default cTab := 'SA1'
	default cCNPJ:= ''

	cTab    := upper(allTrim(cTab))
	cCNPJ   := allTrim(cCNPJ)
	cCpoNome:= if(cTab == 'SA2', 'A2_NOME', 'A1_NOME')
	cMaster := cTab + 'MASTER'
	oModel  := getModel(cMaster)

	if cTab $ 'SA1|SA2' .and. len(cCNPJ) == 14 .and. confirma(oModel)
		if isBlind()
			cRet:= consulta(cTab,cCNPJ,oModel,cMaster)
		else
			FWMsgRun(,{||cRet:= consulta(cTab,cCNPJ,oModel,cMaster)},'CNPJ.ws','Consultando...')
		endif
	endif

	aEval(aArea, {|x| RestArea(x)})

	//Se nao conseguiu consultar, mantem o nome que ja estava no cadastro
	if empty(cRet)
		cRet:= getCampo(oModel,cMaster,cCpoNome)
	endif

return PadR(cRet, TamSX3(cCpoNome)[1])

static function consulta(cTab,cCNPJ,oModel,cMaster)
	local oCNPJws := CNPJws():new()
	local oJSON   := nil
	local oEst    := nil
	local oPais   := nil
	local oIE     := nil
	local aCampos := {}
	local aErros  := {}
	local cPre    := if(cTab == 'SA2', 'A2_', 'A1_')
	local cRet    := ''
	local cSituac := ''
	local cEnd    := ''
	local nX      := 0

	if !oCNPJws:consultarCNPJ(cCNPJ)
		aviso('Erro ao consultar CNPJ: ' + oCNPJws:getError())
		return ''
	endif

	oJSON  := oCNPJws:getResponse()
	oEst   := jObj(oJSON,'estabelecimento')
	cRet   := jStr(oJSON,'razao_social')
	cSituac:= jStr(oEst,'situacao_cadastral')

	if valType(oEst) <> 'J'
		aviso('Retorno da consulta do CNPJ ' + cCNPJ + ' sem os dados do estabelecimento.')
		return cRet
	endif

	if cSituac <> 'Ativa'
		aviso(cCNPJ + ': A situação cadastral da empresa junto a SEFAZ é ' + cSituac)
	endif

	aAdd(aCampos, {cPre + 'MSBLQL', if(cSituac == 'Ativa','2','1')})
	aAdd(aCampos, {if(cTab == 'SA2', 'A2_TIPO', 'A1_PESSOA'), 'J'})

	if gravaCNAE(jObj(oEst,'atividade_principal'))
		aAdd(aCampos, {cPre + 'CNAE', jStr(jObj(oEst,'atividade_principal'),'id')})
	endif

	oPais:= jObj(oEst,'pais')
	if !empty(jStr(oPais,'id'))
		CCH->(dbSetOrder(1))
		if CCH->(dbSeek(xFilial('CCH') + '0' + jStr(oPais,'id')))
			aAdd(aCampos, {cPre + 'CODPAIS', allTrim(CCH->CCH_CODIGO)})
		endif

		SYA->(dbSetOrder(2))
		if SYA->(dbSeek(xFilial('SYA') + upper(jStr(oPais,'nome'))))
			aAdd(aCampos, {cPre + 'PAIS', allTrim(SYA->YA_CODGI)})
		endif
	endif

	aAdd(aCampos, {cPre + 'NREDUZ', if(empty(jStr(oEst,'nome_fantasia')), cRet, jStr(oEst,'nome_fantasia'))})

	//CEP antes do endereco, pois pode ter gatilho que preenche endereco pelo CEP
	aAdd(aCampos, {cPre + 'CEP'    , jStr(oEst,'cep')})
	aAdd(aCampos, {cPre + 'EST'    , jStr(jObj(oEst,'estado'),'sigla')})
	aAdd(aCampos, {cPre + 'COD_MUN', substr(jStr(jObj(oEst,'cidade'),'ibge_id'),3,5)})
	aAdd(aCampos, {cPre + 'BAIRRO' , jStr(oEst,'bairro')})

	cEnd:= jStr(oEst,'logradouro')
	if !empty(jStr(oEst,'numero'))
		cEnd += ', ' + jStr(oEst,'numero')
	endif
	aAdd(aCampos, {cPre + 'END'    , cEnd})
	aAdd(aCampos, {cPre + 'COMPLEM', jStr(oEst,'complemento')})
	aAdd(aCampos, {cPre + 'DDD'    , jStr(oEst,'ddd1')})
	aAdd(aCampos, {cPre + 'TEL'    , jStr(oEst,'telefone1')})

	if !empty(jStr(oEst,'fax'))
		aAdd(aCampos, {cPre + 'FAX', jStr(oEst,'ddd_fax') + jStr(oEst,'fax')})
	endif

	aAdd(aCampos, {cPre + 'EMAIL'  , jStr(oEst,'email')})
	aAdd(aCampos, {cPre + 'SIMPNAC', if(jStr(jObj(oJSON,'simples'),'simples') == 'Sim', '1', '2')})

	if valType(oEst['inscricoes_estaduais']) == 'A'
		for nX:= 1 to len(oEst['inscricoes_estaduais'])
			oIE:= oEst['inscricoes_estaduais'][nX]
			if jStr(jObj(oIE,'estado'),'id') == jStr(jObj(oEst,'estado'),'id')
				aAdd(aCampos, {cPre + 'INSCR', jStr(oIE,'inscricao_estadual')})
				exit
			endif
		next
	endif

	for nX:= 1 to len(aCampos)
		//Nao sobrescreve o cadastro com valores que a API nao retornou
		if !empty(aCampos[nX][2]) .and. !setCampo(oModel,cMaster,aCampos[nX][1],aCampos[nX][2])
			aAdd(aErros, aCampos[nX][1])
		endif
	next

	if !empty(aErros)
		aviso('Os campos abaixo não foram preenchidos por falha na validação: ' + CRLF + arrTokStr(aErros, ', '))
	endif

return cRet

/*/{Protheus.doc} gravaCNAE
Inclui o CNAE na CC3 caso ainda nao exista
/*/
static function gravaCNAE(oAtiv)
	local cCod:= jStr(oAtiv,'id')

	if empty(cCod)
		return .f.
	endif

	CC3->(dbSetOrder(1))
	if !CC3->(dbSeek(xFilial('CC3') + cCod))
		reclock('CC3',.t.)
		CC3->CC3_FILIAL	:= xFilial('CC3')
		CC3->CC3_COD		:= cCod
		CC3->CC3_DESC		:= upper(jStr(oAtiv,'descricao'))
		CC3->CC3_CSECAO	:= jStr(oAtiv,'secao')
		CC3->CC3_CDIVIS	:= jStr(oAtiv,'divisao')
		CC3->CC3_CGRUPO	:= strTran(jStr(oAtiv,'grupo'),'.')
		CC3->CC3_CCLASS	:= strTran(strTran(jStr(oAtiv,'classe'),'.'),'-')
		CC3->(msUnlock())
	endif

return .t.

/*/{Protheus.doc} getModel
Retorna o model MVC ativo caso seja o cadastro da tabela (SA1MASTER/SA2MASTER)
/*/
static function getModel(cMaster)
	local oModel:= FWModelActive()

	if valType(oModel) == 'O' .and. oModel:isActive() .and. valType(oModel:GetModel(cMaster)) == 'O'
		return oModel
	endif

return nil

/*/{Protheus.doc} confirma
Na alteracao pede confirmacao antes de sobrescrever os dados do cadastro
/*/
static function confirma(oModel)
	local lAltera:= .f.

	if isBlind()
		return .t.
	endif

	if oModel <> nil
		lAltera:= oModel:GetOperation() == MODEL_OPERATION_UPDATE
	elseif type('ALTERA') == 'L'
		lAltera:= ALTERA
	endif

return !lAltera .or. MsgYesNo('Deseja atualizar os dados do cadastro com as informações do CNPJ.ws?','CNPJ.ws')

/*/{Protheus.doc} getCampo
Le o valor do campo pelo model MVC ou pela variavel de memoria
/*/
static function getCampo(oModel,cMaster,cCampo)
	local xRet:= ''

	if oModel <> nil
		xRet:= oModel:GetValue(cMaster,cCampo)
	elseif type('M->' + cCampo) <> 'U'
		xRet:= &('M->' + cCampo)
	endif

return if(valType(xRet) == 'C', xRet, '')

/*/{Protheus.doc} setCampo
Grava o valor no campo pelo model MVC ou pela variavel de memoria (executando os gatilhos)
@return logical, .T. se gravou
/*/
static function setCampo(oModel,cMaster,cCampo,xValor)
	local lOk:= .t.

	if empty(GetSX3Cache(cCampo,'X3_CAMPO'))
		return .t. //Campo nao existe no dicionario
	endif

	if valType(xValor) == 'C'
		xValor:= PadR(xValor, TamSX3(cCampo)[1])
	endif

	if oModel <> nil
		lOk:= oModel:SetValue(cMaster,cCampo,xValor)
		if !lOk
			oModel:GetErrorMessage(.t.) //Limpa o erro para nao travar a gravacao do cadastro
		endif
	elseif type('M->' + cCampo) <> 'U'
		&('M->' + cCampo):= xValor
		if ExistTrigger(cCampo)
			RunTrigger(1,Nil,Nil,,cCampo)
		endif
	endif

return lOk

static function jObj(oJSON,cChave)
	local xRet:= nil

	if valType(oJSON) == 'J'
		xRet:= oJSON[cChave]
	endif

return if(valType(xRet) == 'J', xRet, nil)

static function jStr(oJSON,cChave)
	local xRet:= nil

	if valType(oJSON) == 'J'
		xRet:= oJSON[cChave]
	endif

	do case
		case valType(xRet) == 'C'
			return allTrim(xRet)
		case valType(xRet) == 'N'
			return cValToChar(xRet)
	endcase

return ''

static function aviso(cMsg)
	if isBlind()
		conout('CNPJws - getCNPJ: ' + cMsg)
	else
		alert(cMsg)
	endif
return
