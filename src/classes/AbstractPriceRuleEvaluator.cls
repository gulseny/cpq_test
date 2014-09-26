public abstract class AbstractPriceRuleEvaluator extends RuleProcessorSupport {
    public AbstractPriceRuleEvaluator(QuoteVO quote) {  
    	this.quote = quote.record;
    	this.accountId = quote.getAccountId();
    }
    
    public void evaluate() {
        if (!initialized) {
            init();
        }
        
        variableCalculator = new SummaryVariableCalculator(referencedVariables.values());
        variableCalculator.calculate(quote, buildSummaryVariableTargets());
        
        PriceRule__c[] priceRules = getPriceRules();
        SObject[] targetObjects = getTargetRecords();
        for (PriceRule__c ruleRecord : priceRules) {
        	PriceRule rule = new PriceRule(ruleRecord);
            for (Integer i=0;i<targetObjects.size();i++) {
                if (isRuleSatisfied(rule, getEvaluatedRecord(i, targetObjects[i]))) {
                    applyRuleActions(ruleRecord.PriceActions__r, i, targetObjects[i]);
                    
                }
            }
        }
    }      
    
    protected void init() {
    	if (referencedVariables == null) {
        	initSummaryVariables();
    	}    
        initialized = true;
    }
    
    protected void initSummaryVariables() {
    	Set<Id> referencedVariableIds = new Set<Id>();
    	
    	for (PriceRule__c rule : getPriceRules()) {
	        for (PriceCondition__c condition : rule.PriceConditions__r) {
	            if (condition.TestedVariable__c != null) {
	            	referencedVariableIds.add(condition.TestedVariable__c);
	            }
	            if (condition.FilterVariable__c != null) {
	            	referencedVariableIds.add(condition.FilterVariable__c);
	            }
	        }
	        for (PriceAction__c action : rule.PriceActions__r) {
	        	if (action.SourceVariable__c != null) {
	        		referencedVariableIds.add(action.SourceVariable__c);
	        	}
	        }
    	}
        referencedVariables = new Map<Id,SummaryVariable__c>(loadVariables(referencedVariableIds));
    }
    
    private SummaryVariable__c[] loadVariables(Set<Id> varIds) {
    	if (!varIds.isEmpty()) {
    		SummaryVariableDAO dao = new SummaryVariableDAO();
    		return dao.loadByIds(varIds);
    	}
    	return new SummaryVariable__c[]{};
    }
    
    private void applyRuleActions(List<PriceAction__c> priceActions, Integer idx, SObject targetObject) {
        for (PriceAction__c priceAction : priceActions) {
            Schema.SObjectType objectType = targetObject.getSObjectType();
            SObjectField targetField = AliasedMetaDataUtils.getField(objectType, priceAction.Field__c);
            if (targetField != null) {
				if (priceAction.ValueField__c != null) {
                    SObject evaluableObject = getEvaluatedRecord(idx, targetObject);
                    Object value = evaluableObject.get(priceAction.ValueField__c);
                    if (value == null) {
                        targetObject.put(targetField, null);
                    } else {
                        targetObject.put(targetField, QuoteUtils.convertNumber(targetField, value));
                    }
				} else if (priceAction.SourceVariable__c != null) {
                    Object value = variableCalculator.getResult(priceAction.SourceVariable__c);
                    targetObject.put(targetField, value);
				} else {
                    targetObject.put(targetField, (priceAction.Value__c != null) ? QuoteUtils.toObject(targetField, priceAction.Value__c) : null);
                }
            }
        }       
    }

    /* protected void loadQuote() {
        Set<String> fieldNames = new Set<String>();
        List<PriceRule__c> priceRules = getPriceRules();
        for (PriceRule__c priceRule : priceRules) {
            List<PriceCondition__c> priceConditions = priceRule.PriceConditions__r;
            if (priceConditions != null) {
                loadQuoteFieldNames(priceConditions, fieldNames);
            }
        }
        
        Schema.SObjectType quoteType = AliasedMetaDataUtils.determineQuoteType(quoteId);
        QueryBuilder qb = new QueryBuilder(quoteType);
        Boolean hasFields = false;
        for (String fieldName : fieldNames) {
            qb.getSelectClause().addField(fieldName);
            hasFields = true;
        }
        if (hasFields) {
            qb.getWhereClause().addExpression(qb.eq(Quote__c.Id, quoteId));
            quote = Database.query(qb.buildSOQL());         
        } else {
            quote = quoteType.newSObject(quoteId);      
        }
    } */    
    
    private void loadQuoteFieldNames(List<PriceCondition__c> priceConditions, Set<String> fieldNames) {
        for (PriceCondition__c priceCondition : priceConditions) {
            if (priceCondition.Object__c == 'Quote' && priceCondition.Field__c != null) {
                fieldNames.add(priceCondition.Field__c);
            }
        }       
    }  
    
    public abstract PriceRule__c[] getPriceRules();
    
    public class PriceRule extends Rule {
    	public PriceRule(PriceRule__c record) {
    		id = record.Id;
    		conditionsMet = record.ConditionsMet__c;
    		conditions = new RuleCondition[0];
    		for (PriceCondition__c condition : record.PriceConditions__r) {
    			conditions.add(new PriceRuleCondition(condition));
    		}
    	}
    }
    
    public class PriceRuleCondition extends RuleCondition {
    	public PriceRuleCondition(PriceCondition__c condition) {
    		id = condition.Id;
    		testedObject = (condition.Object__c != null) ? condition.Object__c : 'Quote';
    		testedField = condition.Field__c;
    		testedVariableId = condition.TestedVariable__c;
    		operator = condition.Operator__c;
    		filterType = condition.FilterType__c;
    		filterValue = condition.Value__c;
    		filterVariableId = condition.FilterVariable__c;
    	}
    }
 }