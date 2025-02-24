/**
====================================================================================================

  File Name     :     IRIS_PaymentRequestXMLGenerator
  Created By    :     Vishal Thube
  Created Date  :     16-01-2025
  Purpose       :     This class receives Payment Request records, creates an XML file, and stores it into the integration header record.
  
  CHANGE HISTORY: 
       Vishal Thube :   Initial implementation.

======================================================================================================
*/

public class IRIS_PaymentRequestXMLGenerator {
    private Map<String, List<IrisXMLCustomData__mdt>> headerVsFieldsMap = new Map<String, List<IrisXMLCustomData__mdt>>();
    private Map<String, String> documentAttributesMap = new Map<String, String>();
    private Set<String> payFieldsSet = new Set<String>();
    private Set<String> fundingAccountFieldsSet = new Set<String>();
    IntegrationHeader__c iHeader ; 

    public IRIS_PaymentRequestXMLGenerator() {
        fetchMetadata();
    }
/*
        List<PaymentRequest__c> paytList = [Select Id,name from PaymentRequest__c where Id = 'a3lDC000002J5m4YAC' ];
        IntegrationHeader__c iHeader = new IntegrationHeader__c();
            iHeader.Status__c = 'New';
            iHeader.Direction__c = 'From EGMS';
            iHeader.FileName__c = 'IRISFIN.CEDGMS.GRNTPYMT.' + Datetime.now().format('yyyyMMdd-HH-mm-ss');
            insert iHeader;
           PaymentRequestXMLGenerator xmlGenerator = new PaymentRequestXMLGenerator();
               xmlGenerator.processPaymentRequests(payList, iHeader );
           
        
*/
    public void processPaymentRequests(List<PaymentRequest__c> paytList,IntegrationHeader__c iHeader1) {
        
        List<PaymentRequest__c> processedRecords = new List<PaymentRequest__c>();
                iHeader = iHeader1;
        
                payFieldsSet.add('Id'); 
                FundingAccountFieldsSet.add('Id'); 
            String payFieldList = String.join(new List<String>(payFieldsSet), ', ');
            String FundingAccountFieldList = String.join(new List<String>(FundingAccountFieldsSet), ', ');
            
            System.debug('Generated payFieldList: ' + payFieldList);
            System.debug('Generated FundingAccountFieldList: ' + FundingAccountFieldList);            
            String query= 'SELECT  ' + payFieldList + ', (Select ' + FundingAccountFieldList + ' from AwardFundingAccounts__r) FROM PaymentRequest__c WHERE Id IN :paytList';

            System.debug('Generated Query: ' + query);
            List<PaymentRequest__c> paymentRequests = Database.query(query);
            

        
        
        
        Dom.Document doc = new Dom.Document();
        Dom.XmlNode root = doc.createRootElement('AMS_DOC_XML_IMPORT_FILE', null, null);
        
        //system.debug('paymentRequests-->'+paymentRequests);
        for (PaymentRequest__c objPay : paymentRequests) {
            
            Dom.XmlNode amsDocument = root.addChildElement('AMS_DOCUMENT', null, null);
            setDocumentAttributes(amsDocument, objPay);

            for (String header : headerVsFieldsMap.keySet()) {
                if (header == 'PR_DOC_ACTG' && objPay.AwardFundingAccounts__r != null && !objPay.AwardFundingAccounts__r.isEmpty()) {
                    for (AwardFundingAccount__c payFA : objPay.AwardFundingAccounts__r) {
                        generateHeaderXml(amsDocument, header, headerVsFieldsMap.get(header), payFA);
                    }
                } else {
                    generateHeaderXml(amsDocument, header, headerVsFieldsMap.get(header), objPay);
                }
            }
            objPay.AL_xmlFileStatus__c = 'Generated';
            objPay.AL_IntegrationHeader__c= iHeader.Id;
            processedRecords.add(objPay);
        }

        String xmlString = doc.toXmlString();        
        saveAsAttachment(iHeader,xmlString);
        PaymentRequestTriggerHelper.skipTrigger = true;
        AwardTriggerHelper.skipTrigger = true;
        GrantTriggerHelper.skipTrigger = true;
        if(!processedRecords.isEmpty()) Update processedRecords; 
    }

    private void fetchMetadata() {
        for (IrisXMLCustomData__mdt customData : [
            SELECT DeveloperName, HeaderType__c, DefaultValue__c, VNT_AttributeApiName__c, ObjectFieldAPIName__c, VNT_ObjectApiName__c,HeaderSequence__c 
            FROM IrisXMLCustomData__mdt where XML_Type__c = 'PRC' order By HeaderSequence__c ASC
        ]) {
            if(customData.HeaderType__c == 'PR_DOC_Document_Attributes'){
                documentAttributesMap.put(customData.VNT_AttributeApiName__c, 
                                        customData.defaultValue__c != null ? customData.defaultValue__c : customData.ObjectFieldAPIName__c);
            
            }else{
                if (!headerVsFieldsMap.containsKey(customData.HeaderType__c)) {
                    headerVsFieldsMap.put(customData.HeaderType__c, new List<IrisXMLCustomData__mdt>());
                }
                headerVsFieldsMap.get(customData.HeaderType__c).add(customData);
    
                if (customData.DefaultValue__c == null) {
                    if (customData.VNT_ObjectApiName__c == 'PaymentRequest__c') {
                        payFieldsSet.add(customData.ObjectFieldAPIName__c);
                    }
                    if (customData.VNT_ObjectApiName__c == 'AwardFundingAccount__c') {
                        fundingAccountFieldsSet.add(customData.ObjectFieldAPIName__c);
                    }
                }
           }
        }
    }

    private void setDocumentAttributes(Dom.XmlNode amsDocument, PaymentRequest__c objPay) {
    
    
        if(documentAttributesMap.containsKey('DOC_CAT'))         amsDocument.setAttribute('DOC_CAT', documentAttributesMap.get('DOC_CAT'));
        if(documentAttributesMap.containsKey('DOC_TYP'))         amsDocument.setAttribute('DOC_TYP', documentAttributesMap.get('DOC_TYP'));
        if(documentAttributesMap.containsKey('DOC_CD'))          amsDocument.setAttribute('DOC_CD', documentAttributesMap.get('DOC_CD'));
        if(documentAttributesMap.containsKey('DOC_DEPT_CD'))     amsDocument.setAttribute('DOC_DEPT_CD', documentAttributesMap.get('DOC_DEPT_CD'));
        if(documentAttributesMap.containsKey('DOC_UNIT_CD'))     amsDocument.setAttribute('DOC_UNIT_CD', documentAttributesMap.get('DOC_UNIT_CD'));
    
        if (documentAttributesMap.containsKey('DOC_ID')) {
            amsDocument.setAttribute('DOC_ID', (String) objPay.get(documentAttributesMap.get('DOC_ID')));
        }
        
        if(documentAttributesMap.containsKey('DOC_VERS_NO'))      amsDocument.setAttribute('DOC_VERS_NO', documentAttributesMap.get('DOC_VERS_NO'));
        if(documentAttributesMap.containsKey('AUTO_DOC_NUM'))     amsDocument.setAttribute('AUTO_DOC_NUM', documentAttributesMap.get('AUTO_DOC_NUM'));
        if(documentAttributesMap.containsKey('DOC_IMPORT_MODE'))  amsDocument.setAttribute('DOC_IMPORT_MODE', documentAttributesMap.get('DOC_IMPORT_MODE'));
    }

    private void generateHeaderXml(Dom.XmlNode parentNode, String header, List<IrisXMLCustomData__mdt> fields, SObject record) {
        Dom.XmlNode awardDocHdr = parentNode.addChildElement(header, null, null);
        awardDocHdr.setAttribute('AMSDataObject', 'Y');
    
        for (IrisXMLCustomData__mdt field : fields) {
            String elementName = field.VNT_AttributeApiName__c;
            String fieldPath = field.ObjectFieldAPIName__c;
            Dom.XmlNode fieldNode = awardDocHdr.addChildElement(elementName, null, null);
            fieldNode.setAttribute('Attribute', 'Y');
    
            Object fieldValue = null;
            if (field.DefaultValue__c != null) {
                fieldValue = field.DefaultValue__c;
            } else if (record != null && String.isNotBlank(fieldPath)) {
                List<String> fieldParts = fieldPath.split('\\.');
                
                SObject currentRecord = record;
                // Traverse relationships without try-catch using safe navigation
                for (Integer i = 0; i < fieldParts.size() - 1 && currentRecord != null; i++) {
                    currentRecord = currentRecord.getSObject(fieldParts[i]);
                }
    
                if (currentRecord != null) {
                    String leafField = fieldParts[fieldParts.size() - 1];
                    try {
                        fieldValue = currentRecord.get(leafField);
                    } catch (Exception e) {
                        System.debug('Invalid field access: ' + fieldPath + '\n' + e.getStackTraceString());
                    }
                }
            }
    
            fieldNode.addTextNode(fieldValue != null ? String.valueOf(fieldValue) : '');
        }
    }

    private void saveAsAttachment(IntegrationHeader__c iHeader, String xmlString) {
        if (String.isNotEmpty(xmlString)) {
           
            Attachment attachment = new Attachment();
            attachment.ParentId = iHeader.Id;
            attachment.Name = iHeader.FileName__c+'.xml';
            attachment.Body = Blob.valueOf(xmlString);
            attachment.ContentType = 'application/xml';
            insert attachment;
        }
    }
}