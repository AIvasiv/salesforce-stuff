//**
// Author: Andrii Ivasiv
// Date: August 28, 2020
// Description: pull all of the fields from page layoput based on the record type
// 
//**

public with sharing class ChecklistHFHPercentageController {
    @AuraEnabled
    public static Decimal calculateHFHChecklistPercentage(Id idOfChecklistRecord){
        Checklist__c checklistToWorkWith = [SELECT id, RecordTypeId, Percentage_Completed__c FROM Checklist__c WHERE id =: idOfChecklistRecord];
        Set<String> fieldNames = getListOfFieldsOnPageLayout(checklistToWorkWith.RecordTypeId);
        String sObjectName = idOfChecklistRecord.getSObjectType().getDescribe().getName();      
        Integer totalNumberOfFields = fieldNames.size();

        String soqlQuery = ' SELECT ' + String.join((Iterable<String>)fieldNames, ',') + ' FROM ' + sObjectName + ' Where Id =: idOfChecklistRecord';
        
        List<sObject> records = Database.query(soqlQuery);
        Decimal numberOfFields = 0;
        for(String strIterator: fieldNames){
            //We don`t calculate fields that are empty or false
            if(records[0].get(strIterator) != null && records[0].get(strIterator) != '' && records[0].get(strIterator) != false){
                numberOfFields++;
            }
        }
        Decimal finalPercentage = (numberOfFields/totalNumberOfFields)*100;

        checklistToWorkWith.Percentage_Completed__c = finalPercentage.round(System.RoundingMode.CEILING);
        update checklistToWorkWith;
        return finalPercentage.round(System.RoundingMode.CEILING);
    }

    private static Set<String> getListOfFieldsOnPageLayout(id recordtypeid){
        String sfdcURL = URL.getSalesforceBaseUrl().toExternalForm(); 

        Http initHTTP = new Http();
        HttpRequest httpReqGetItem = new HttpRequest();
            httpReqGetItem.setEndpoint('callout:CalculateFieldsForChecklist/services/data/v40.0/sobjects/Checklist__c/describe');
            httpReqGetItem.setMethod('GET');
            httpReqGetItem.setHeader('Content-Type', 'application/json');
        HttpResponse httpRespWithToken = initHTTP.send(httpReqGetItem);
        Map<String, Object> metadata_Map = (Map<String, Object>) JSON.deserializeUntyped(httpRespWithToken.getBody());
        
        String urlForLayoutRetreive;

        List<Object> listOfInfoWithRecordTypes = (List<Object>) metadata_Map.get('recordTypeInfos');

        for(Object objectItr: listOfInfoWithRecordTypes){
            Map<String,Object> mapWithInfo = (Map<String,Object>) objectItr;
            if(mapWithInfo.get('recordTypeId') == recordtypeid){
                Map<String,Object> mapWithInfoForLayout = (Map<String,Object>) mapWithInfo.get('urls');
                urlForLayoutRetreive = (String)mapWithInfoforLayout.get('layout');
            }
        }
        return getFieldsFromLayout(urlForLayoutRetreive);
    }

    private static Set<String> getFieldsFromLayout(String linkToLayout){
        Http initHTTP = new Http();

        HttpRequest httpReqGetItem = new HttpRequest();
            httpReqGetItem.setMethod('GET');
            httpReqGetItem.setHeader('Content-Type', 'application/json');
            httpReqGetItem.setEndpoint('callout:CalculateFieldsForChecklist' + linkToLayout);
        HttpResponse httpRespWithToken = initHTTP.send(httpReqGetItem);

        Map<String, Object> metadata_Map = (Map<String, Object>) JSON.deserializeUntyped(httpRespWithToken.getBody());
        List<Object> listOfLayoutSections = (List<Object>) metadata_Map.get('detailLayoutSections');        
        List<Object> listOfLayoutRows = new List<Object>();
        for(Object objectItr: listOfLayoutSections){
            Map<String,Object> mapWithLayoutSections = (Map<String,Object>) objectItr;
            for(String sectionItr: mapWithLayoutSections.keySet()){
                if(sectionItr == 'layoutRows'){
                    listOfLayoutRows.add((List<Object>) mapWithLayoutSections.get(sectionItr));
                }
            }
        }
        List<Object> listOfLayoutComponents = new List<Object>();
        for(Object objectItr: listOfLayoutRows){
            List<Object> innerList = (List<Object>)objectItr;
            for(Object innerObjectItr: innerList){
                Map<String,Object> mapWithLayoutItems = (Map<String,Object>) innerObjectItr;
                for(String sectionItr: mapWithLayoutItems.keySet()){
                    if(sectionItr == 'layoutItems'){
                        listOfLayoutComponents.add((List<Object>) mapWithLayoutItems.get(sectionItr));
                    }
                }
            }
        }
        Set<String> setOfFieldsName = new Set<String>();
        for(Object objectItrUpper: listOfLayoutComponents){
            List<Object> innerList = (List<Object>)objectItrUpper;
            for(Object objectItr: innerList){
                Map<String,Object> mapWithLayoutSections = (Map<String,Object>) objectItr;
                List<Object> innerListDown = (List<Object>) mapWithLayoutSections.get('layoutComponents');
                for(Object innerIterator: innerListDown){
                    Map<String,Object> mapWithLayoutSectionsInner = (Map<String,Object>) innerIterator;
                    setOfFieldsName.add((String)mapWithLayoutSectionsInner.get('value'));
                }
            }
        }

        for(String strIterator: setOfFieldsName){
            //Record Type, Status, Program Enrollment and every field which contains If Applicable shouldn't be added in field set
            if(strIterator.contains('If Applicable') || strIterator == 'RecordTypeId' || strIterator == 'Status__c' || strIterator == 'Program_Enrollment__c' ){
                setOfFieldsName.remove(strIterator);
            }
        }

        return setOfFieldsName;
    }
}