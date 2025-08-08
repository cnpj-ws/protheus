#include 'totvs.ch'

/*/{Protheus.doc} SyncCNPJ
Sincroniza os dados do CNPJ com o sistema.
@type function
@version 1.0
@author Carlos Tirabassi
@since 8/7/2025
@param aEmp, array, Ambiente a ser utilizado
/*/
user function SyncCNPJ(aEmp)
	local cLog      := ''
	local nRegs     := 0
	local oJSON     := nil
	local oCNPJws   := nil

	default aEmp:= {'01','010001'}

	if !rpcSetEnv(aEmp[1], aEmp[2])
		conout('CNPJws - SyncCNPJ: Erro ao setar ambiente')
		return
	endif

	cLog += 'Iniciando sincronização de CNPJ: ' + time() + Chr( 13 ) + Chr( 10 )

	oCNPJws:= CNPJws():new()

	SA2->(dbSetOrder(1))
	while SA2->(!eof())
		if SA2->A2_MSBLQL <> '1'
			if SA2->A2_TIPO == 'J' .and. !Empty(SA2->A2_CGC)
				if oCNPJws:consultarCNPJ(alltrim(SA2->A2_CGC))
					oJSON:= oCNPJws:getResponse()
					syncSA2(oJSON)
					nRegs++
				endif
			endif
		endif
		SA2->(dbSkip())
	enddo

	cLog += 'Total de registros: ' + alltrim(str(nRegs)) + Chr( 13 ) + Chr( 10 )
	cLog += 'Sincronização de CNPJ finalizada: ' + time()
	conout(cLog)

	rpcClearEnv()

return

static function syncSA2(oJSON)
	local aArea:= FWGetArea()
	local oModel:= nil
	local nX:= 0
	local lOk:= .f.
	local aErro:= {}
	local cLog := ''
	local cCGC := SA2->A2_CGC

	if valType(oJSON) == 'U'
		conout('CNPJws - SyncCNPJ: Erro ao consultar CNPJ')
		return
	endif

	oModel := FWLoadModel("MATA020M")
	oModel:SetOperation(4)
	oModel:Activate()

	oModel:SetValue('SA2MASTER','A2_MSBLQL' ,if(oJSON['estabelecimento']['situacao_cadastral'] == 'Ativa','2','1'))

	oModel:SetValue('SA2MASTER','A2_NOME', oJSON['razao_social'])

	if !empty(oJSON['estabelecimento']['nome_fantasia'])
		oModel:SetValue('SA2MASTER','A2_NREDUZ',avKey(oJSON['estabelecimento']['nome_fantasia'],'A2_NREDUZ'))
	else
		oModel:SetValue('SA2MASTER','A2_NREDUZ',avKey(oJSON['razao_social'], 'A2_NREDUZ'))
	endif

	CC3->(dbSetOrder(1))
	if !CC3->(dbSeek(xFilial('CC3')+oJSON['estabelecimento']['atividade_principal']['id']))
		reclock('CC3',.t.)
		CC3->CC3_FILIAL	:= xFilial('CC3')
		CC3->CC3_COD	:= oJSON['estabelecimento']['atividade_principal']['id']
		CC3->CC3_DESC	:= upper(oJSON['estabelecimento']['atividade_principal']['descricao'])
		CC3->CC3_CSECAO	:= oJSON['estabelecimento']['atividade_principal']['secao']
		CC3->CC3_CDIVIS	:= oJSON['estabelecimento']['atividade_principal']['divisao']
		CC3->CC3_CGRUPO	:= strTran(oJSON['estabelecimento']['atividade_principal']['grupo'],'.')
		CC3->CC3_CCLASS	:= strTran(strTran(oJSON['estabelecimento']['atividade_principal']['classe'],'.'),'-')
		CC3->(msUnlock())
	endif

	oModel:SetValue('SA2MASTER','A2_CNAE',oJSON['estabelecimento']['atividade_principal']['id'])

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

	oModel:SetValue('SA2MASTER','A2_CEP', oJSON['estabelecimento']['cep'])

	oModel:SetValue('SA2MASTER','A2_EST', oJSON['estabelecimento']['estado']['sigla'])

	oModel:SetValue('SA2MASTER','A2_COD_MUN', substring(cValToChar(oJSON['estabelecimento']['cidade']['ibge_id']),3,5))

	oModel:SetValue('SA2MASTER','A2_BAIRRO', oJSON['estabelecimento']['bairro'])

	oModel:SetValue('SA2MASTER','A2_END',oJSON['estabelecimento']['logradouro'] + ', ' + oJSON['estabelecimento']['numero'])

	oModel:SetValue('SA2MASTER','A2_COMPLEM', oJSON['estabelecimento']['complemento'])

	oModel:SetValue('SA2MASTER','A2_DDD', oJSON['estabelecimento']['ddd1'])

	oModel:SetValue('SA2MASTER','A2_TEL', oJSON['estabelecimento']['telefone1'])

	oModel:SetValue('SA2MASTER','A2_FAX', oJSON['estabelecimento']['ddd_fax']+oJSON['estabelecimento']['fax'])

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

	If oModel:VldData()
		If oModel:CommitData()
			lOk := .T.
		Else
			lOk := .F.
		EndIf
	Else
		lOk := .F.
	EndIf

	If !lOk
		aErro := oModel:GetErrorMessage()

		//Monta o Texto que será mostrado na tela
        cLog+= 'Erro ao sincronizar CNPJ: ' + cCGC + Chr( 13 ) + Chr( 10 )
		cLog+= "Id do formulário de origem:"  + ' [' + AllToChar(aErro[01]) + ']' + Chr( 13 ) + Chr( 10 )
		cLog+= "Id do campo de origem: "      + ' [' + AllToChar(aErro[02]) + ']' + Chr( 13 ) + Chr( 10 )
		cLog+= "Id do formulário de erro: "   + ' [' + AllToChar(aErro[03]) + ']' + Chr( 13 ) + Chr( 10 )
		cLog+= "Id do campo de erro: "        + ' [' + AllToChar(aErro[04]) + ']' + Chr( 13 ) + Chr( 10 )
		cLog+= "Id do erro: "                 + ' [' + AllToChar(aErro[05]) + ']' + Chr( 13 ) + Chr( 10 )
		cLog+= "Mensagem do erro: "           + ' [' + AllToChar(aErro[06]) + ']' + Chr( 13 ) + Chr( 10 )
		cLog+= "Mensagem da solução: "        + ' [' + AllToChar(aErro[07]) + ']' + Chr( 13 ) + Chr( 10 )
		cLog+= "Valor atribuído: "            + ' [' + AllToChar(aErro[08]) + ']' + Chr( 13 ) + Chr( 10 )
		cLog+= "Valor anterior: "             + ' [' + AllToChar(aErro[09]) + ']' + Chr( 13 ) + Chr( 10 )

		conout(cLog)
	EndIf

	oModel:DeActivate()
	oModel:Destroy()

	FWRestArea(aArea)

return
