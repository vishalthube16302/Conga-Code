/**
====================================================================================================

  File Name     :     IRIS_DisbursementFileExtractor
  Created By    :     Vishal Thube
  Created Date  :     11-02-2025
  Purpose       :     This class receives integration header records, retrieves files from these records, 
                      extracts TXT content, and processes it into expenditure staging objects.
    
  CHANGE HISTORY: 
      Vishal Thube :   Initial implementation.

======================================================================================================
*/

public class IRIS_DisbursementFileExtractor {
    
  public Static List<FieldProcessingInfo> processingInfos = new List<FieldProcessingInfo>();

    public static void extractFile(IntegrationHeader__c headerRecords) {
        integer LineNumber = 0;
        fetchMetadata ();
        try {
            if (processingInfos.isEmpty()) {
                headerRecords.Status__c = 'Failed';
                headerRecords.Log__c = 'Please check Metadata... No valid fields in IRISDisbursementFileMapping__mdt';
                update headerRecords;
                return;
            }

            // Process file content
            List<expenditure_staging_object__c> insertStaging = new List<expenditure_staging_object__c>();
            String content ;
            List<Attachment> files = [SELECT Body FROM Attachment WHERE ParentId = :headerRecords.Id ORDER BY CreatedDate DESC LIMIT 1];
            
            if (!files.isEmpty()) {
                content = files[0].Body.toString();
            }else{
  
                List<ContentVersion > contentfiles = [Select Id,ContentDocumentId ,VersionData from ContentVersion 
                                    where ContentDocumentId in (Select ContentDocumentId  from ContentDocumentLink where LinkedEntityId = :headerRecords.Id) ORDER BY CreatedDate DESC LIMIT 1];
                if(!contentfiles.isEmpty()) content = contentfiles[0].VersionData.toString(); // Convert Blob to String
            }
            if (String.isNotEmpty(content)) {

                List<String> lines = content.split('\n');
                
                // Sort in ascending order
                lines.sort();
                
                for (String line : lines) {
                    if (String.isBlank(line)) continue;
                    LineNumber = LineNumber  + 1;
                    expenditure_staging_object__c record = new expenditure_staging_object__c();
                    
                    for (FieldProcessingInfo info : processingInfos) {
                        String val = line.substring(info.fromIndex, info.toIndex).trim();

                        switch on info.fieldType {
                            when 'STRING', 'PICKLIST' {
                                record.put(info.apiName, val);
                            }
                            when 'DATE' {
                                if (val.length() >= 8) {
                                    record.put(info.apiName, 
                                        Date.newInstance(
                                            Integer.valueOf(val.substring(0,4)),
                                            Integer.valueOf(val.substring(4,6)),
                                            Integer.valueOf(val.substring(6,8))
                                        )
                                    );
                                }
                            }
                            when 'DOUBLE', 'CURRENCY' {
                                Decimal num = String.isBlank(val) ? 0 : Decimal.valueOf(val);
                                record.put(info.apiName, num);
                            }
                            when 'DATETIME' {
                                if (val.length() >= 14) {
                                    record.put(info.apiName, 
                                        DateTime.newInstanceGmt(
                                            Integer.valueOf(val.substring(0,4)),
                                            Integer.valueOf(val.substring(4,6)),
                                            Integer.valueOf(val.substring(6,8)),
                                            Integer.valueOf(val.substring(8,10)),
                                            Integer.valueOf(val.substring(10,12)),
                                            Integer.valueOf(val.substring(12,14))
                                        )
                                    );
                                }
                            }
                        }
                    }
                    record.Processing_Status__c = 'Ready to Process';
                    insertStaging.add(record);
                }
                if (!insertStaging.isEmpty()) {
                    ExpenStagingTriggerHelper.skipTrigger = true;
                    insert insertStaging;
                }
    
                headerRecords.Status__c = 'Completed';
                update headerRecords;
                System.debug('Heap Size: ' + Limits.getHeapSize() + ' / ' + Limits.getLimitHeapSize());
                System.debug('CPU Time: ' + Limits.getCpuTime() + ' / ' + Limits.getLimitCpuTime());
            }else{
                headerRecords.Status__c = 'Failed';
                headerRecords.Log__c ='There is no file attached in the integration header record.';
                update headerRecords;
            }

            


        } catch (Exception e) {
            headerRecords.Status__c = 'Failed';
            headerRecords.Log__c ='Getting and Error Line Number :- '+ LineNumber +' ' + e.getMessage() + '\n' + e.getStackTraceString();
            update headerRecords;
        }
    }
    
    public static void fetchMetadata (){
         // Pre-fetch object field metadata once
            Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                .get('expenditure_staging_object__c')
                .getDescribe()
                .fields.getMap();

            // Preprocess custom metadata to extract field info
            for (IRISDisbursementFileMapping__mdt mdt : [SELECT FieldAPIName__c, ExtractTextFrom__c, ExtractTextTo__c FROM IRISDisbursementFileMapping__mdt
                WHERE FieldAPIName__c != NULL
            ]) {
                String apiName = mdt.FieldAPIName__c;
                Schema.SObjectField field = fieldMap.get(apiName);
                if (field == null) continue;

                Schema.DescribeFieldResult dfr = field.getDescribe();
                String fieldType = dfr.getType().name().toUpperCase();

                Integer fromIdx = (mdt.ExtractTextFrom__c != null) ? mdt.ExtractTextFrom__c.intValue() - 1 : 0;
                Integer toIdx = (mdt.ExtractTextTo__c != null) ? mdt.ExtractTextTo__c.intValue() : 0;

                processingInfos.add(new FieldProcessingInfo(apiName, fromIdx, toIdx, fieldType));
            }
    }
    
    private class FieldProcessingInfo {
        public String apiName;
        public Integer fromIndex;
        public Integer toIndex;
        public String fieldType;

        public FieldProcessingInfo(String apiName, Integer fromIndex, Integer toIndex, String fieldType) {
            this.apiName = apiName;
            this.fromIndex = fromIndex;
            this.toIndex = toIndex;
            this.fieldType = fieldType;
        }
    }
}