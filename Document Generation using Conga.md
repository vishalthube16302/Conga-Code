# Conga Composer Integration with Salesforce

This repository demonstrates how to integrate Conga Composer with Salesforce for generating documents like awards, NOGAs, and amendments. The code showcases two approaches to achieve this integration:

1. **Using the Conga Interface**
2. **Using the Conga API**

---

## Features
- Dynamic document generation with Conga Composer
- Template-based document creation
- Integration with Salesforce objects and templates
- REST API-based document generation

---

## Code Overview

### 1. Using Conga Interface

This method dynamically constructs the Conga Composer URL based on the Salesforce record and template details.

**Key Steps:**
- Fetch the Conga Solution record.
- Replace placeholders in the button body with the appropriate Salesforce values.
- Handle specific actions (e.g., View NOGA, View Amendment NOGA) for file naming.

```apex
global String generateComposer(sObject record, String SolutionName, String SolutionTemplateKeyId , String TemplateName){
 
    String PARTNER_URL = URL.getSalesforceBaseUrl().toExternalForm() + '/services/Soap/u/37.0/' + UserInfo.getOrganizationId();
    

    APXTConga4__Conga_Solution__c congaSolutionRecord = [SELECT Id, name, APXTConga4__Button_body_field__c FROM APXTConga4__Conga_Solution__c 
    WHERE Name LIKE :SolutionName LIMIT 1]; 
    system.debug('congaSolutionRecord =====>'+congaSolutionRecord );
    String congaComposerURL;                      
    congaComposerURL = congaSolutionRecord.APXTConga4__Button_body_field__c;
    congaComposerURL = congaComposerURL.replace('{!Award__c.Id}', record.Id);
    congaComposerURL = congaComposerURL.replace('{!API.Partner_Server_URL_370}',PARTNER_URL);
    
    String templateParameter ; 
    if (!String.isBlank(TemplateName)) {
        templateParameter = [SELECT Id, APXTConga4__Name__c, APXTConga4__Key__c 
                    FROM APXTConga4__Conga_Template__c WHERE APXTConga4__Name__c LIKE :TemplateName LIMIT 1].APXTConga4__Key__c ;
    
    }

    
    congaComposerURL = congaComposerURL.replace(SolutionTemplateKeyId , templateParameter );
     if(actionName == 'View NOGA') congaComposerURL += ('&OFN=Award+Noga' + record.get('Name'));
     if(actionName =='View Amendment NOGA') congaComposerURL += ('&OFN=Amendment+Noga' + record.get('Name'));
    system.debug('congaComposerURL =====>'+congaComposerURL );  
     
    return congaComposerURL;
   
 }

```

### 2. Using API

This method uses the Conga Composer API to generate and fetch documents programmatically.

**Key Steps:**
- Replace placeholders in the Conga Composer URL.
- Construct the endpoint using the Conga Composer API base URL.
- Make an HTTP request to generate the document and fetch the response.

```apex

private Boolean generateAwardTemplateDocument(Award__c record, String congaComposerURL, String templateId) {
		
		private static final String PARTNER_URL = URL.getOrgDomainUrl().toExternalForm() + '/services/Soap/u/58.0/' + UserInfo.getOrganizationId();
		private static final String BASE_CONGA_API_URL = 'https://composer.congamerge.com/composer8/index.html?SessionId=' + UserInfo.getSessionId();
	
        if (String.isEmpty(templateId)) {
            System.debug('No matching template found.');
            return false;
        }
        
        congaComposerURL = congaComposerURL.replace('{!Award__c.Id}', record.Id);
        congaComposerURL = congaComposerURL.replace('{!API.Partner_Server_URL_520}', PARTNER_URL);
        System.debug('congaComposerURL::::'+congaComposerURL);
        List<String> splitString = congaComposerURL.split('&QueryId', 2);
        System.debug('splitString::: '+splitString);
        
        DateTime now = DateTime.now();
        String formattedDate = now.format('MMddyyyyHHmmss');
        String fileName = 'Grant_Agreement_' + formattedDate;

        String endpoint = BASE_CONGA_API_URL + '&Id=' + record.Id + '&ServerUrl=' + PARTNER_URL + '&QueryId' + splitString[1].deleteWhitespace() + '&OFN=' + fileName + '&templateid=' + templateId;

        System.debug('Constructed Endpoint: ' + endpoint);

        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setTimeout(120000);
        request.setEndpoint(endpoint);
        Http http = new Http();
        HttpResponse response = http.send(request);
        if (response.getStatusCode() == 200) {
            System.debug('Document generated successfully.');
            System.debug('Response: ' + response.getBody());
            return true;
        } 
        else {
            System.debug('Document generation failed. Status code: ' + response.getStatusCode());
            System.debug('Response body: ' + response.getBody());
            return false;
        }
    }
```

---

## Prerequisites

- Salesforce org with Conga Composer installed.
- Conga Composer templates set up with placeholders.
- Required Salesforce objects and fields created, including `Award__c`.

---

## How to Use

### 1. Using the Conga Interface
- Pass the Salesforce record, solution name, template key ID, and template name to the `generateComposer` method.
- The method returns a URL that can be used to generate the document.

### 2. Using API
- Pass the Salesforce record, Conga Composer URL, and template ID to the `generateAwardTemplateDocument` method.
- The method makes an HTTP GET request and returns whether the document generation was successful.

---

## Debugging

Use `System.debug` statements to trace the flow of URL construction, API requests, and responses:
- Validate Conga Solution record fetching.
- Ensure placeholders in URLs are replaced correctly.
- Check HTTP response codes and bodies for errors.

---



---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
