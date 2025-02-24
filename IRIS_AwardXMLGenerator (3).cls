/**
====================================================================================================

  File Name     :     IRIS_AwardXMLGenerator
  Created By    :     Vishal Thube
  Created Date  :     16-01-2025
  Purpose       :     This class receives Award records, creates an XML file, and stores it into the integration header record.
  
  CHANGE HISTORY: 
       Vishal Thube :   Initial implementation.

======================================================================================================
*/

/*
List<Award__c> paytList = [Select ID,Name from Award__c where  id = 'a2uDC000001k0MzYAI'];
        IntegrationHeader__c iHeader = new IntegrationHeader__c();
            iHeader.Status__c = 'New';
            iHeader.Direction__c = 'From EGMS';
            iHeader.FileName__c = 'AWD' + String.valueOf(System.NOW()).replaceAll(':','-');
            insert iHeader;
           IRIS_AwardXMLGenerator xmlGenerator = new IRIS_AwardXMLGenerator();
               xmlGenerator.processAwards(paytList, iHeader );


*/

public class IRIS_AwardXMLGenerator {
    private Map<String, List<IrisXMLCustomData__mdt>> headerVsFieldsMap = new Map<String, List<IrisXMLCustomData__mdt>>();
    private Map<String, String> documentAttributesMap = new Map<String, String>();

    private Set<String> awardFieldsSet = new Set<String>();
    private Set<String> fundingAccountFieldsSet = new Set<String>();
    IntegrationHeader__c iHeader ; 

    public IRIS_AwardXMLGenerator() {
        fetchMetadata();
    }

    public void processAwards(List<Award__c> awardList, IntegrationHeader__c iHeader1) {
        
        List<Award__c> processedRecords = new List<Award__c>();
        iHeader = iHeader1;
        
        awardFieldsSet.add('Id'); 
        fundingAccountFieldsSet.add('Id'); 
        
        String awardFieldList = String.join(new List<String>(awardFieldsSet), ', ');
        String fundingAccountFieldList = String.join(new List<String>(fundingAccountFieldsSet), ', ');
        
        System.debug('Generated awardFieldList: ' + awardFieldList);
        System.debug('Generated fundingAccountFieldList: ' + fundingAccountFieldList);            
        
        String query = 'SELECT ' + awardFieldList + ', (SELECT ' + fundingAccountFieldList + ' FROM AwardFundingAccounts__r) FROM Award__c WHERE Id IN :awardList';
        System.debug('Generated Query: ' + query);
        
        List<Award__c> awards = Database.query(query);

        Dom.Document doc = new Dom.Document();
        Dom.XmlNode root = doc.createRootElement('AMS_DOC_XML_IMPORT_FILE', null, null);
        
        for (Award__c objAward : awards) {

            Dom.XmlNode amsDocument = root.addChildElement('AMS_DOCUMENT', null, null);
            setDocumentAttributes(amsDocument, objAward);

            for (String header : headerVsFieldsMap.keySet()) {
                if (header == 'PO_DOC_ACTG' && objAward.AwardFundingAccounts__r != null && !objAward.AwardFundingAccounts__r.isEmpty()) {
                    for (AwardFundingAccount__c awardFA : objAward.AwardFundingAccounts__r) {
                        generateHeaderXml(amsDocument, header, headerVsFieldsMap.get(header), awardFA);
                    }
                } else {
                    generateHeaderXml(amsDocument, header, headerVsFieldsMap.get(header), objAward);
                }
            }
            objAward.AL_xmlFileStatus__c = 'Generated';
            objAward.AL_IntegrationHeader__c = iHeader.Id;
            processedRecords.add(objAward);
        }

        String xmlString = doc.toXmlString();
             
        saveAsAttachment(iHeader, xmlString);
        AwardTriggerHelper.skipTrigger = true;
        if (!processedRecords.isEmpty()) Update processedRecords; 
    }

    private void fetchMetadata() {
        for (IrisXMLCustomData__mdt customData : [
            SELECT DeveloperName, HeaderType__c, DefaultValue__c, VNT_AttributeApiName__c, ObjectFieldAPIName__c, VNT_ObjectApiName__c,HeaderSequence__c 
            FROM IrisXMLCustomData__mdt where XML_Type__c = 'PO3' order By HeaderSequence__c ASC
        ]) {
            if(customData.HeaderType__c == 'PO_DOC_Document_Attributes'){
                documentAttributesMap.put(customData.VNT_AttributeApiName__c, 
                                        customData.defaultValue__c != null ? customData.defaultValue__c : customData.ObjectFieldAPIName__c);
            
            }else{
                if (!headerVsFieldsMap.containsKey(customData.HeaderType__c)) {
                    headerVsFieldsMap.put(customData.HeaderType__c, new List<IrisXMLCustomData__mdt>());
                }
                headerVsFieldsMap.get(customData.HeaderType__c).add(customData);
    
                if (customData.DefaultValue__c == null) {
                if (customData.VNT_ObjectApiName__c == 'Award__c') {
                    awardFieldsSet.add(customData.ObjectFieldAPIName__c);
                }
                if (customData.VNT_ObjectApiName__c == 'AwardFundingAccount__c') {
                    fundingAccountFieldsSet.add(customData.ObjectFieldAPIName__c);
                }
            }
           }
        }
    }

    
    private void setDocumentAttributes(Dom.XmlNode amsDocument, Award__c objAward) {
    
    
        if(documentAttributesMap.containsKey('DOC_CAT'))         amsDocument.setAttribute('DOC_CAT', documentAttributesMap.get('DOC_CAT'));
        if(documentAttributesMap.containsKey('DOC_TYP'))         amsDocument.setAttribute('DOC_TYP', documentAttributesMap.get('DOC_TYP'));
        if(documentAttributesMap.containsKey('DOC_CD'))          amsDocument.setAttribute('DOC_CD', documentAttributesMap.get('DOC_CD'));
        if(documentAttributesMap.containsKey('DOC_DEPT_CD'))     amsDocument.setAttribute('DOC_DEPT_CD', documentAttributesMap.get('DOC_DEPT_CD'));
        if(documentAttributesMap.containsKey('DOC_UNIT_CD'))     amsDocument.setAttribute('DOC_UNIT_CD', documentAttributesMap.get('DOC_UNIT_CD'));
    
        if (documentAttributesMap.containsKey('DOC_ID')) {
            amsDocument.setAttribute('DOC_ID', (String) objAward.get(documentAttributesMap.get('DOC_ID')));
        }
        
        if(documentAttributesMap.containsKey('DOC_VERS_NO'))      amsDocument.setAttribute('DOC_VERS_NO', documentAttributesMap.get('DOC_VERS_NO'));
        if(documentAttributesMap.containsKey('AUTO_DOC_NUM'))     amsDocument.setAttribute('AUTO_DOC_NUM', documentAttributesMap.get('AUTO_DOC_NUM'));
        if(documentAttributesMap.containsKey('DOC_IMPORT_MODE'))  amsDocument.setAttribute('DOC_IMPORT_MODE', documentAttributesMap.get('DOC_IMPORT_MODE'));
    }

    private void generateHeaderXml(Dom.XmlNode parentNode, String header, List<IrisXMLCustomData__mdt> fields, SObject record) {
         String sObjectTypeName = String.valueOf(record.getSObjectType());

        
        Dom.XmlNode awardDocHdr = parentNode.addChildElement(header, null, null);
        awardDocHdr.setAttribute('AMSDataObject', 'Y');
    
        for (IrisXMLCustomData__mdt field : fields) {
            if ((sObjectTypeName == 'Award__c' && header != 'PO_DOC_ACTG') || (sObjectTypeName == 'AwardFundingAccount__c' && header == 'PO_DOC_ACTG')) {
                Dom.XmlNode fieldNode = awardDocHdr.addChildElement(field.VNT_AttributeApiName__c, null, null);
                fieldNode.setAttribute('Attribute', 'Y');
                Object fieldValue = null;
                if (field.DefaultValue__c != null) {
                    fieldValue= field.DefaultValue__c;
                } else if (record != null) {
                        try {
                            if (field.ObjectFieldAPIName__c.contains('.')) { // Check for relationship fields
                                List<String> fieldParts = field.ObjectFieldAPIName__c.split('\\.');
                                SObject currentRecord = record;
    
                                for (Integer i = 0; i < fieldParts.size() - 1; i++) { 
                                    if (currentRecord == null) {
                                        break;
                                    }
                                    currentRecord = currentRecord.getSObject(fieldParts[i]); // Traverse relationships
                                }
    
                                if (currentRecord != null) {
                                    fieldValue = currentRecord.get(fieldParts[fieldParts.size() - 1]); // Get final field value
                                }
                            } else {
                                fieldValue = record.get(field.ObjectFieldAPIName__c); // Direct field
                            }
                        } catch (Exception e) {
                             System.debug('Error Occurred: ' + e.getMessage() + 
                                ' | Record Id = ' + record.Id + 
                                ' | XML File Information: ' + 
                                ' Header = ' + field.HeaderType__c + 
                                ' | Attribute = ' + field.VNT_AttributeApiName__c + 
                                ' | Field = ' + field.ObjectFieldAPIName__c);
                            
                            System.debug('Stack Trace: ' + e.getStackTraceString());
                        }
                }
                    
                
                
                fieldNode.addTextNode(fieldValue != null ? String.valueOf(fieldValue) : '');
            }
         }
    }

    private void saveAsAttachment(IntegrationHeader__c iHeader, String xmlString) {
        if (String.isNotEmpty(xmlString)) {
            Attachment attachment = new Attachment();
            attachment.ParentId = iHeader.Id;
            attachment.Name = iHeader.FileName__c + '.xml';
            attachment.Body = Blob.valueOf(xmlString);
            attachment.ContentType = 'application/xml';
            insert attachment;
        }
    }
}