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
global String generateComposer(sObject record, String SolutionName, String SolutionTemplateKeyId , String TemplateName) {
    // Constructs the Conga Composer URL for document generation.
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
    // Sends an HTTP GET request to Conga Composer for document generation.
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

## Example

Below is a snippet to invoke document generation via the API:

```apex
Award__c award = [SELECT Id, Name FROM Award__c LIMIT 1];
String congaURL = '<CongaComposerURL>';
String templateId = '<TemplateID>';

Boolean isGenerated = generateAwardTemplateDocument(award, congaURL, templateId);

if (isGenerated) {
    System.debug('Document generated successfully.');
} else {
    System.debug('Failed to generate document.');
}
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
