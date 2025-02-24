/**
====================================================================================================

  File Name     :     IRIS_DisbursementFileExtractorBatch
  Created By    :     Vishal Thube
  Created Date  :     11-02-2025
  Purpose       :     This batch class retrieves integration header records received from AWS and processes the 
                      records in batches.
    
  NOTE          :     Execute this batch class with a single batch size to ensure proper processing.
  
  CHANGE HISTORY: 
      Vishal Thube :   Initial implementation.

======================================================================================================
*/

global Class IRIS_DisbursementFileExtractorBatch extends GNT.BatchApexHandler implements Database.Stateful {
    Id integrationHeaderId ;

    
    global IRIS_DisbursementFileExtractorBatch () {
        
    }

    global IRIS_DisbursementFileExtractorBatch (Id integrationHeaderId) {
        this.integrationHeaderId = integrationHeaderId;
    }
    
     global override String getQuery() {
       
        String query ;
        if (integrationHeaderId != null) {
            query = 'SELECT Id, Status__c, Filename__c, Log__c FROM IntegrationHeader__c WHERE Id = \'' +integrationHeaderId + '\'';
        }else{
            query = 'SELECT Id, Status__c, Filename__c,Log__c  FROM IntegrationHeader__c WHERE Status__c = \'Ready for Processing\' AND Direction__c = \'To EGMS\' ';
        }
       
        return query;
        
    }
    global override void execute(List<SObject> scope) {
        List<IntegrationHeader__c> headers = (List<IntegrationHeader__c>) scope;
        
        for (IntegrationHeader__c header : headers) {
            IRIS_DisbursementFileExtractor.extractFile(header );
        }
    }
    global override void finish() {
        
    }
    
}