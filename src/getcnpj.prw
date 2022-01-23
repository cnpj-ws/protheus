#include 'totvs.ch'

/*/{Protheus.doc} getCNPJ
Gatilho para o cadastro de cliente e fornecedor. Exemplo de cadastro do gatilho:
Campo				: A1_CGC ou A2_CGC
Cnt. Dominio: A1_NOME ou A2_NOME
Tipo				: 1
Regra				: u_getCNPJ('SA1',M->A1_CGC) ou u_getCNPJ('SA2',M->A2_CGC) 
Posiciona		: 2
Condicao		: !empty(M->A1_CGC) ou !empty(M->A2_CGC)
@type function
@version 1.0 
@author Carlos Tirabassi
@since 08/06/2021
@param cTab, character, Passar a tabela (SA1 ou SA2)
@param cCNPJ, character, CNPJ
@return character, razão social
/*/
user function getCNPJ(cTab,cCNPJ)
	local aArea:= getArea()
	local cRet := ''

	default cTab := 'SA1'
	default cCNPJ:= ''

	cCNPJ:= allTrim(cCNPJ)

	if !empty(cTab) .and. len(cCNPJ) == 14
		if isBlind()
			cRet:= consulta(cTab,cCNPJ)
		else
			FWMsgRun(,{||cRet:= consulta(cTab,cCNPJ)},'CNPJ.ws','Consultando...')
		endif
	endif

	restArea(aArea)

return cRet

static function consulta(cTab,cCNPJ)
	local oCNPJws:= CNPJws():new()
	local oJSON  := nil
	local nX     := 1
	local cRet   := ''
	local lJob   := isBlind()
	local oModel := nil

	if oCNPJws:consultarCNPJ(cCNPJ)
		oJSON:= oCNPJws:getResponse()

		cRet:= oJSON['razao_social']

		if oJSON['estabelecimento']['situacao_cadastral'] <> 'Ativa'
			if lJob
				conout(cCNPJ + ': A situação cadastral da empresa junto a SEFAZ é ' + oJSON['estabelecimento']['situacao_cadastral'])
			else
				alert('A situação cadastral da empresa junto a SEFAZ é ' + oJSON['estabelecimento']['situacao_cadastral'])
			endif
		endif

		if cTab == 'SA1'

			M->A1_MSBLQL:= if(oJSON['estabelecimento']['situacao_cadastral'] == 'Ativa','2','1')
			If ExistTrigger('A1_MSBLQL')
				RunTrigger(1,Nil,Nil,,'A1_MSBLQL')
			Endif

			M->A1_CNAE:= oJSON['estabelecimento']['atividade_principal']['id']

			CC3->(dbSetOrder(1))
			if !CC3->(dbSeek(xFilial('CC3')+M->A1_CNAE))
				reclock('CC3',.t.)
				CC3->CC3_FILIAL	:= xFilial('CC3')
				CC3->CC3_COD		:= oJSON['estabelecimento']['atividade_principal']['id']
				CC3->CC3_DESC		:= upper(oJSON['estabelecimento']['atividade_principal']['descricao'])
				CC3->CC3_CSECAO	:= oJSON['estabelecimento']['atividade_principal']['secao']
				CC3->CC3_CDIVIS	:= oJSON['estabelecimento']['atividade_principal']['divisao']
				CC3->CC3_CGRUPO	:= strTran(oJSON['estabelecimento']['atividade_principal']['grupo'],'.')
				CC3->CC3_CCLASS	:= strTran(strTran(oJSON['estabelecimento']['atividade_principal']['classe'],'.'),'-')
				CC3->(msUnlock())
			endif
			If ExistTrigger('A1_CNAE')
				RunTrigger(1,Nil,Nil,,'A1_CNAE')
			Endif

			M->A1_PESSOA	:= 'J'
			If ExistTrigger('A1_PESSOA')
				RunTrigger(1,Nil,Nil,,'A1_CNAE')
			Endif

			if !empty(oJSON['estabelecimento']['pais']['id'])
				CCH->(dbSetOrder(1))
				if CCH->(dbSeek(xFilial('CCH')+ '0' + oJSON['estabelecimento']['pais']['id'] ))
					M->A1_CODPAIS	:=  CCH->CCH_CODIGO
					If ExistTrigger('A1_CODPAIS')
						RunTrigger(1,Nil,Nil,,'A1_CODPAIS')
					Endif
				endif

				SYA->(dbSetOrder(2))
				if SYA->(dbSeek(xFilial('SYA')+ upper(oJSON['estabelecimento']['pais']['nome'])))
					M->A1_PAIS	:= SYA->YA_CODGI
					If ExistTrigger('A1_PAIS')
						RunTrigger(1,Nil,Nil,,'A1_PAIS')
					Endif
				endif
			endif

			M->A1_NREDUZ := oJSON['estabelecimento']['nome_fantasia']

			if empty(M->A1_NREDUZ) //Caso nao possua nome fantasia
				M->A1_NREDUZ := avKey(cRet, 'A1_NREDUZ')
			endif

			If ExistTrigger('A1_NREDUZ')
				RunTrigger(1,Nil,Nil,,'A1_NREDUZ')
			Endif

			M->A1_CEP		:= oJSON['estabelecimento']['cep']
			If ExistTrigger('A1_CEP')
				RunTrigger(1,Nil,Nil,,'A1_CEP')
			Endif

			M->A1_EST		:= oJSON['estabelecimento']['estado']['sigla']
			If ExistTrigger('A1_EST')
				RunTrigger(1,Nil,Nil,,'A1_EST')
			Endif

			M->A1_COD_MUN:= substring(cValToChar(oJSON['estabelecimento']['cidade']['ibge_id']),3,5)
			If ExistTrigger('A1_COD_MUN')
				RunTrigger(1,Nil,Nil,,'A1_COD_MUN')
			Endif

			M->A1_BAIRRO := oJSON['estabelecimento']['bairro']
			If ExistTrigger('A1_BAIRRO')
				RunTrigger(1,Nil,Nil,,'A1_BAIRRO')
			Endif

			M->A1_END    := oJSON['estabelecimento']['logradouro'] + ', ' + oJSON['estabelecimento']['numero']
			If ExistTrigger('A1_END')
				RunTrigger(1,Nil,Nil,,'A1_END')
			Endif

			M->A1_COMPLEM:= oJSON['estabelecimento']['complemento']
			If ExistTrigger('A1_COMPLEM')
				RunTrigger(1,Nil,Nil,,'A1_COMPLEM')
			Endif

			M->A1_DDD		:= oJSON['estabelecimento']['ddd1']
			If ExistTrigger('A1_DDD')
				RunTrigger(1,Nil,Nil,,'A1_DDD')
			Endif

			M->A1_TEL		:= oJSON['estabelecimento']['telefone1']
			If ExistTrigger('A1_TEL')
				RunTrigger(1,Nil,Nil,,'A1_TEL')
			Endif

			M->A1_FAX		:= oJSON['estabelecimento']['ddd_fax']+oJSON['estabelecimento']['fax']
			If ExistTrigger('A1_FAX')
				RunTrigger(1,Nil,Nil,,'A1_FAX')
			Endif

			M->A1_EMAIL	:= oJSON['estabelecimento']['email']
			If ExistTrigger('A1_EMAIL')
				RunTrigger(1,Nil,Nil,,'A1_EMAIL')
			Endif

			if valType(oJSON['simples']) == 'J'
				M->A1_SIMPNAC:= if(oJSON['simples']['simples'] == 'Sim', '1', '2')
			else
				M->A1_SIMPNAC:= '2'
			endif
			If ExistTrigger('A1_SIMPNAC')
				RunTrigger(1,Nil,Nil,,'A1_SIMPNAC')
			Endif

			for nX:=1 to len(oJSON['estabelecimento']['inscricoes_estaduais'])
				if oJSON['estabelecimento']['estado']['id'] == oJSON['estabelecimento']['inscricoes_estaduais'][nX]['estado']['id']
					M->A1_INSCR:= oJSON['estabelecimento']['inscricoes_estaduais'][nX]['inscricao_estadual']
					If ExistTrigger('A1_INSCR')
						RunTrigger(1,Nil,Nil,,'A1_INSCR')
					Endif
					EXIT
				endif
			next

		elseIf cTab == 'SA2'

			//MATA020 está em MVC
			oModel := FWModelActive()

			oModel:SetValue('SA2MASTER','A2_MSBLQL' ,if(oJSON['estabelecimento']['situacao_cadastral'] == 'Ativa','2','1'))

			CC3->(dbSetOrder(1))
			if !CC3->(dbSeek(xFilial('CC3')+oJSON['estabelecimento']['atividade_principal']['id']))
				reclock('CC3',.t.)
				CC3->CC3_FILIAL	:= xFilial('CC3')
				CC3->CC3_COD		:= oJSON['estabelecimento']['atividade_principal']['id']
				CC3->CC3_DESC		:= upper(oJSON['estabelecimento']['atividade_principal']['descricao'])
				CC3->CC3_CSECAO	:= oJSON['estabelecimento']['atividade_principal']['secao']
				CC3->CC3_CDIVIS	:= oJSON['estabelecimento']['atividade_principal']['divisao']
				CC3->CC3_CGRUPO	:= strTran(oJSON['estabelecimento']['atividade_principal']['grupo'],'.')
				CC3->CC3_CCLASS	:= strTran(strTran(oJSON['estabelecimento']['atividade_principal']['classe'],'.'),'-')
				CC3->(msUnlock())
			endif

			oModel:SetValue('SA2MASTER','A2_CNAE',oJSON['estabelecimento']['atividade_principal']['id'])

			oModel:SetValue('SA2MASTER','A2_TIPO', 'J')

			if !empty(oJSON['estabelecimento']['pais']['id'])
				CCH->(dbSetOrder(1))
				if CCH->(dbSeek(xFilial('CCH') + '0' + oJSON['estabelecimento']['pais']['id']))
					oModel:SetValue('SA2MASTER','A2_CODPAIS', allTrim(CCH->CCH_CODIGO))
				endif

				SYA->(dbSetOrder(2))
				if SYA->(dbSeek(xFilial('SYA')+ upper(oJSON['estabelecimento']['pais']['nome'])))
					oModel:SetValue('SA2MASTER','A2_PAIS', allTrim(SYA->YA_CODGI))
				endif
			endif

			if !empty(oJSON['estabelecimento']['nome_fantasia'])
				oModel:SetValue('SA2MASTER','A2_NREDUZ',oJSON['estabelecimento']['nome_fantasia'])
			else
				oModel:SetValue('SA2MASTER','A2_NREDUZ',avKey(cRet, 'A2_NREDUZ'))
			endif

			oModel:SetValue('SA2MASTER','A2_CEP', oJSON['estabelecimento']['cep'])

			oModel:SetValue('SA2MASTER','A2_EST', oJSON['estabelecimento']['estado']['sigla'])

			oModel:SetValue('SA2MASTER','A2_COD_MUN', substring(cValToChar(oJSON['estabelecimento']['cidade']['ibge_id']),3,5))

			oModel:SetValue('SA2MASTER','A2_BAIRRO', oJSON['estabelecimento']['bairro'])

			oModel:SetValue('SA2MASTER','A2_END',oJSON['estabelecimento']['logradouro'] + ', ' + oJSON['estabelecimento']['numero'])

			oModel:SetValue('SA2MASTER','A2_COMPLEM', oJSON['estabelecimento']['complemento'])

			oModel:SetValue('SA2MASTER','A2_DDD', oJSON['estabelecimento']['ddd1'])

			oModel:SetValue('SA2MASTER','A2_TEL', oJSON['estabelecimento']['telefone1'])

			oModel:SetValue('SA2MASTER','A2_FAX', oJSON['estabelecimento']['ddd_fax']+oJSON['estabelecimento']['fax'])

			oModel:SetValue('SA2MASTER','A2_EMAIL', oJSON['estabelecimento']['email'])

			if valType(oJSON['simples']) == 'J'
				oModel:SetValue('SA2MASTER','A2_SIMPNAC', if(oJSON['simples']['simples'] == 'Sim', '1', '2'))
			else
				oModel:SetValue('SA2MASTER','A2_SIMPNAC', '2')
			endif

			for nX:=1 to len(oJSON['estabelecimento']['inscricoes_estaduais'])
				if oJSON['estabelecimento']['estado']['id'] == oJSON['estabelecimento']['inscricoes_estaduais'][nX]['estado']['id']
					oModel:SetValue('SA2MASTER','A2_INSCR', oJSON['estabelecimento']['inscricoes_estaduais'][nX]['inscricao_estadual'])
					EXIT
				endif
			next
		endif

	else
		if lJob
			conout('Erro ao consultar CNPJ: ' + oCNPJws:getError())
		else
			alert('Erro ao consultar CNPJ: ' + oCNPJws:getError())
		endif
	endif

return cRet
