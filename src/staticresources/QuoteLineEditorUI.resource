function QuoteLineEditorCtrl(scope, sce, controllerManager, metaDataService, quoteService) {
	controllerManager.register('QuoteLineEditor', this);
	
	this.scope = scope;
	this.scope.sce = sce;
	this.scope.controllerManager = controllerManager;
	this.scope.active = false;
	this.scope.controller = this;
	this.scope.quoteService = quoteService;
	this.scope.metaDataService = metaDataService;
	this.scope.blockingOperationInProgress = false;
	
	// Add event handlers to scope.
	this.scope.onDeleteLine = this.onDeleteLine;
	this.scope.onDeleteLines = this.onDeleteLines;
	this.scope.onEditLine = this.onEditLine;
	this.scope.onChangeValue = this.onChangeValue;
	this.scope.onChangeUnit = this.onChangeUnit;
	this.scope.onLoad = this.onLoad;
	this.scope.onSave = this.onSave;
	this.scope.onExecuteCustomAction = this.onExecuteCustomAction;
	this.scope.onAddProducts = this.onAddProducts;
	this.scope.onRenewSubscriptions = this.onRenewSubscriptions;
	this.scope.onUpgradeAssets = this.onUpgradeAssets;
	this.scope.onReconfigureLine = this.onReconfigureLine;
	this.scope.onAddGroup = this.onAddGroup;
	this.scope.onDeleteGroup = this.onDeleteGroup;
	this.scope.onCloneGroup = this.onCloneGroup;
	this.scope.onCalculate =  this.onCalculate;
	this.scope.onCancel =  this.onCancel;
	this.scope.onResetDiscounts =  this.onResetDiscounts;
	this.scope.onDropRow = this.onDropRow;
	this.scope.load = this.load;
	
	this.richTextEditor = null;
}
QuoteLineEditorCtrl.$inject = ['$scope', '$sce', 'controllerManager', 'metaDataService', 'quoteServiceProxy'];
QuoteLineEditorCtrl.prototype = new Controller();

QuoteLineEditorCtrl.prototype.onDeactivate = function() {
	// Move editor model out of scope to reduce the amount of processing Angular needs to do
	this.editorModel = this.scope.editorModel;
	this.scope.editorModel = null;
}

QuoteLineEditorCtrl.prototype.onActivate = function() {
	// Move editor model back in scope
	this.scope.editorModel = this.editorModel;
	this.editorModel = null;
}

QuoteLineEditorCtrl.prototype.onDropRow = function(event, ui) {
	if (ui.draggable) {
		var target = event.target;
		var srcKey = ui.draggable.attr('key');
		var targetKey = target.getAttribute('key');
		this.editorModel.quote.moveLine(srcKey, targetKey);
		this.$apply();
	}
}

QuoteLineEditorCtrl.prototype.onLoad = function(/*String*/ quoteId, /*String*/ usedObjects) {
	var controller = this.controller;
	this.active = true;
	this.blockingOperationInProgress = true;
	controller.load(this.controller, quoteId, usedObjects);
}

QuoteLineEditorCtrl.prototype.load = function(/*Controller*/ srcController, /*String*/ quoteId, /*String*/ usedObjects) {
	var scope = this.scope;
	var successHandler = function(/*String*/ result) {
		//console.log(angular.toJson(angular.fromJson(result), true));
		scope.controller.editorModel = new QuoteEditorModel(scope, angular.fromJson(result));
		scope.referencedObjects = scope.controller.editorModel.referencedObjects;
		scope.metaDataService.setExternalFieldMetadata(scope.controller.editorModel.fieldMetadata);
		var quote = scope.controller.editorModel.quote;
		if (ModelUtils.isBlank(quote.getPricebookId())) {
			var retUrl = window.location.href;
			if (retUrl.indexOf('cp=1') > -1) {
				document.location.assign('/' + quote.getId());
				return;
			}
			retUrl = retUrl + '&cp=1';
			document.location.assign('/oppitm/choosepricebook.jsp?id=' + quote.getOpportunityId() + '&retURL=' + encodeURIComponent(retUrl));
			return;
		}
		s2 = new Date();
		scope.blockingOperationInProgress = false;
		scope.controllerManager.activateController(scope.controller);
		if (console) {
			console.log('Total Time:' + ((new Date()).getTime() - s1.getTime()) + '; Render Time: ' + ((new Date()).getTime() - s2.getTime()));
		}
		//console.log(angular.toJson(scope.editorModel.quote, true));
	};
	var s1;
	var metaDataCompleteHandler = function() {
		s1 = new Date();
		scope.quoteService.loadQuoteEditor(quoteId, successHandler, srcController.createErrorHandler());
	}
	
	var prefix = scope.metaDataService.getPrefix();
	var objectNames = [prefix + 'Quote__c',prefix + 'QuoteLine__c',prefix + 'QuoteLineGroup__c',prefix+'WebQuote__c',prefix+'WebQuoteLine__c'];
	if (!ModelUtils.isBlank(usedObjects)) {
		objectNames = usedObjects.split(',');
	}
	scope.metaDataService.ensureObjectMetaData(objectNames, metaDataCompleteHandler, srcController.createErrorHandler());
}

QuoteLineEditorCtrl.prototype.onSave = function() {
	var controller = this.controller;
	this.blockingOperationInProgress = true;
	this.messages = null;
	
	var scope = this;
	var successHandler = function(/*String[]*/ messages) {
		if ((messages != null) && (messages.length > 0)) {
			scope.messages = [];
			angular.forEach(messages, function(msg) {
				this.messages.push({severity:'error',summary:scope.sce.trustAsHtml(msg)});
			}, scope);
			scope.blockingOperationInProgress = false;
			scope.$apply();
		} else {
			if (controller.isSalesforce1()) {
				sforce.one.navigateToSObject(scope.editorModel.quote.record.Id, 'detail');
			} else if (controller.isPhoneGap()) {
				var targetCtrl = this.controllerManager.lookup('QuoteDetail');
				targetCtrl.load(controller);
			} else {
				document.location.assign('/' + scope.editorModel.quote.record.Id);
			}
		}
	};
	scope.quoteService.saveQuote(scope.editorModel.copyQuote(true), successHandler, this.controller.createErrorHandler());
}

QuoteLineEditorCtrl.prototype.onCancel = function() {
	var controller = this.controller;
	this.blockingOperationInProgress = true;
	this.messages = null;
	
	if (controller.isSalesforce1()) {
		sforce.one.navigateToSObject(this.editorModel.quote.record.Id, 'detail');
	} else if (controller.isPhoneGap()) {
		var targetCtrl = this.controllerManager.lookup('QuoteDetail');
		targetCtrl.load(controller);
	} else {
		document.location.assign('/' + this.editorModel.quote.record.Id);
	}
}

QuoteLineEditorCtrl.prototype.onCalculate = function() {
	var scope = this.controller.scope;
	scope.blockingOperationInProgress = true;
	scope.messages = null;
	
	var successHandler = function(/*QuoteVO*/ result) {
		//console.log('IN\n' + angular.toJson(angular.fromJson(result), true));
		var s2 = new Date();
		scope.editorModel.updateQuote(angular.fromJson(result));
		scope.blockingOperationInProgress = false;
		scope.$apply();
		if (console) {
			console.log('Calculate | Total Time:' + ((new Date()).getTime() - s1.getTime()) + '; Render Time: ' + ((new Date()).getTime() - s2.getTime()));
		}
		scope.controller.refocus();
	};
	s1 = new Date();
	var quote = scope.editorModel.copyQuote(true);
	//console.log('OUT\n' + angular.toJson(quote, true));
	scope.quoteService.calculateQuote(quote, successHandler, this.controller.createErrorHandler());
}

QuoteLineEditorCtrl.prototype.onRenewSubscriptions = function(/*CustomActionModel*/ action, /*Integer*/ targetGroupKey) {
	var scope = this.controller.scope;
	scope.blockingOperationInProgress = true;
	scope.messages = null;
	var quote = this.editorModel.copyQuote(false);
	var slc = scope.controllerManager.lookup('SubscriptionLookup');
	slc.load(this.controller, quote, (targetGroupKey == undefined) ? null : targetGroupKey, action.id);
}

QuoteLineEditorCtrl.prototype.onUpgradeAssets = function(/*CustomActionModel*/ action, /*Integer*/ targetGroupKey) {
	var scope = this.controller.scope;
	scope.blockingOperationInProgress = true;
	scope.messages = null;
	var quote = this.editorModel.copyQuote(false);
	var alc = this.controllerManager.lookup('AssetLookup');
	alc.load(this.controller, quote, (targetGroupKey == undefined) ? null : targetGroupKey, action.id);
}

QuoteLineEditorCtrl.prototype.onReconfigureLine = function(/*QuoteLineModel*/ line) {
	var scope = this.controller.scope;
	scope.blockingOperationInProgress = true;
	scope.messages = null;
	var quote = this.editorModel.copyQuote(true);
	var successHandler = function(/*String*/ result) {
		var targetCtrl = scope.controllerManager.lookup('ProductConfigurator');
		targetCtrl.configureProducts(scope.controller, scope.editorModel.copyQuote(false), [angular.fromJson(result)]);
	}
	this.quoteService.reconfigureQuoteLine(quote, line.key, successHandler, scope.controller.createErrorHandler());
}

QuoteLineEditorCtrl.prototype.onExecuteCustomAction = function(/*CustomActionModel*/ action, /*Integer*/ targetGroupKey) {
	if (action.isTargetProduct()) {
		this.onAddProducts(action, targetGroupKey);
	} else if (action.isTargetAsset()) {
		this.onUpgradeAssets(action, targetGroupKey);
	} else if (action.isTargetSubscription()) {
		this.onRenewSubscriptions(action, targetGroupKey);
	} 
}

QuoteLineEditorCtrl.prototype.onAddProducts = function(/*CustomActionModel*/ action, /*Integer*/ targetGroupKey) {
	var scope = this.controller.scope;
	scope.blockingOperationInProgress = true;
	scope.messages = null;
	targetGroupKey = (targetGroupKey == undefined) ?  null : targetGroupKey;
	var targetGroup = (targetGroupKey != null) ? this.editorModel.quote.groupsByKey[targetGroupKey] : null;
	var quoteProcessId = this.editorModel.quote.record[QuoteModel.QUOTE_PROCESS_ID_FIELD];
	quoteProcessId = (quoteProcessId == undefined) ?  null : quoteProcessId;
	var groupProcessId = (targetGroup != null) ? targetGroup.record[QuoteLineGroupModel.QUOTE_PROCESS_FIELD] : null;
	groupProcessId = (groupProcessId == undefined) ?  null : groupProcessId;
	var quote = this.editorModel.copyQuote(false);
	var plc = this.controllerManager.lookup('ProductLookup');
	var processId = ModelUtils.isBlank(groupProcessId) ? (ModelUtils.isBlank(quoteProcessId) ? null : quoteProcessId) : groupProcessId;
	plc.load(this.controller, quote, targetGroupKey, processId, action.id);
}

QuoteLineEditorCtrl.prototype.addProducts = function(/*Controller*/ srcController, /*Integer*/ targetGroupKey, /*ProductVO[]*/ selectedProducts, /*QuoteProcessVO*/ quoteProcess) {
	var controller = this;
	var scope = controller.scope;
	
	var successHandler = function(/*String*/ result) {
		//console.log(angular.toJson(angular.fromJson(result), true));
		scope.productSelectionModel = new ProductSelectionModel(angular.fromJson(result));
		var quote = scope.productSelectionModel.quote;
		var configs = scope.productSelectionModel.configuredProducts;
		var upgrades = scope.productSelectionModel.upgradeProducts;
		var targetCtrl = controller;
		if ((upgrades.length == 0) && (configs.length == 0)) {
			controller.editorModel.updateQuote(scope.productSelectionModel.quote);
			delete scope.productSelectionModel;
			
			var productLookupCtrl = scope.controllerManager.lookup('ProductLookup');
			if (productLookupCtrl.scope.addMore) {
				productLookupCtrl.load(srcController, controller.editorModel.copyQuote(true), targetGroupKey, productLookupCtrl.scope.quoteProcessId, productLookupCtrl.scope.searchModel.actionId);
			} else {
				scope.controllerManager.activateController(targetCtrl);
			}
		} else {
			// Keep originally selected products to preserve order and stand-alone product selections.
			scope.productSelectionModel.selectedProducts = selectedProducts;
			scope.productSelectionModel.quoteProcess = quoteProcess;
			scope.productSelectionModel.targetGroupKey = targetGroupKey;
			if (upgrades.length > 0) {
				targetCtrl = scope.controllerManager.lookup('ProductUpgrader');
				targetCtrl.selectUpgradedAssets(upgrades);
			} else if (configs.length > 0) {
				targetCtrl = scope.controllerManager.lookup('ProductConfigurator');
				targetCtrl.scope.currencySymbol = controller.editorModel.currencySymbol;
				targetCtrl.configureProducts(srcController, quote, configs);
			}
		}
	};
	
	var quote = controller.editorModel.copyQuote(true);
	//console.log(angular.toJson(quote, true) + ' Group KEY: ' + targetGroupKey);
	//console.log(angular.toJson(selectedProducts, true));
	scope.quoteService.addProducts(quote, targetGroupKey, selectedProducts, quoteProcess, successHandler, srcController.createErrorHandler());
}

QuoteLineEditorCtrl.prototype.renewSubscriptions = function(/*Controller*/ srcController, /*Integer*/ targetGroupKey, /*SubscriptionVO[]*/ selectedSubscriptions) {
	var controller = this;
	var scope = controller.scope;
	
	var successHandler = function(/*String*/ result) {
		controller.editorModel.updateQuote(angular.fromJson(result));
		scope.controllerManager.activateController(controller);
	};
	
	var quote = controller.editorModel.copyQuote(true);
	scope.quoteService.renewSubscriptions(quote, targetGroupKey, selectedSubscriptions, successHandler, srcController.createErrorHandler());
}

QuoteLineEditorCtrl.prototype.onEditLine = function(/*QuoteLineModel*/ line) {
	var scope = this.controller.scope;
	var ctrl = scope.controller;
	scope.editedLines = [line];
	scope.editLineMode = true;
}

QuoteLineEditorCtrl.prototype.onDeleteLine = function(/*Integer*/ lineKey) {
	var scope = this.controller.scope;
	var ctrl = this.controller;
	scope.blockingOperationInProgress = true;
	scope.messages = null;
	
	scope.quoteService.deleteLines(scope.editorModel.copyQuote(true), [lineKey], ctrl.createUpdateHandler(), ctrl.createErrorHandler());
}

QuoteLineEditorCtrl.prototype.onDeleteLines = function() {
	var scope = this;
	var lineKeys = scope.editorModel.quote.getSelectedLineKeys();
	var ctrl = this.controller;
	scope.blockingOperationInProgress = true;
	scope.messages = null;
	
	scope.quoteService.deleteLines(scope.editorModel.copyQuote(true), lineKeys, ctrl.createUpdateHandler(), ctrl.createErrorHandler());
}

QuoteLineEditorCtrl.prototype.onDeleteGroup = function(/*Integer*/ groupKey) {
	var scope = this.controller.scope;
	var ctrl = this.controller;
	scope.blockingOperationInProgress = true;
	scope.messages = null;
	
	scope.quoteService.deleteGroup(scope.editorModel.copyQuote(true), groupKey, ctrl.createUpdateHandler(), ctrl.createErrorHandler());
}

QuoteLineEditorCtrl.prototype.onCloneGroup = function(/*Integer*/ groupKey) {
	var scope = this.controller.scope;
	var ctrl = this.controller;
	scope.blockingOperationInProgress = true;
	scope.messages = null;
	
	scope.quoteService.cloneGroup(scope.editorModel.copyQuote(true), groupKey, ctrl.createUpdateHandler(), ctrl.createErrorHandler());
}

QuoteLineEditorCtrl.prototype.onAddGroup = function() {
	var solutionGroup = this.editorModel.settings.solutionGroupsEnabled ? this.editorModel.selectedSolutionGroup : null;
	this.editorModel.quote.addGroup(solutionGroup);
}

QuoteLineEditorCtrl.prototype.onChangeUnit = function(/*Field*/ field, /*QuoteLineModel*/ line) {
	if (field.name == QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD) {
		line.changeAdditionalDiscountUnit();
	} else if (field.name == QuoteLineModel.MARKUP_FIELD) {
		line.changeMarkupUnit();
	}
}

QuoteLineEditorCtrl.prototype.onResetDiscounts = function(/*QuoteLineGroupModel*/ group) {
	angular.forEach(group.lineItems, function(item) {
		item.resetAdditionalDiscount();
	}, this);
}

QuoteLineEditorCtrl.prototype.onChangeValue = function(/*Event*/ event, /*Field*/ field, /*Object*/ target) {
	if ((target instanceof QuoteLineGroupModel) && (field != null) && (field.name == QuoteLineGroupModel.OPTIONAL_FIELD)) {
		target.updateLineOptional(target.isOptional());
	}
	
	if (this.editorModel.settings.calculateImmediately) {
		this.onCalculate();
	}
}

QuoteLineEditorCtrl.prototype.getRichTextEditor = function() {
	if (this.richTextEditor == null) {
		this.richTextEditor = new DescriptionEditorDialog(this.scope);
		this.richTextEditor.register();
	}
	return this.richTextEditor;
}

QuoteLineEditorCtrl.prototype.createUpdateHandler = function() {
	var controller = this;
	var scope = controller.scope;
	return function(/*String*/ result) {
		scope.editorModel.updateQuote(angular.fromJson(result));
		scope.blockingOperationInProgress = false;
		scope.$apply();
	};
}



function QuoteEditorModel(/*Scope*/ scope, /*Object*/ data) {
	ModelUtils.copyProperties(data, this);
	this.scope = scope;
	this.metaDataService = scope.metaDataService;
	this.initMetaData();
	this.quote = new QuoteModel(this, data.quote);
	this.quote.renumber();
	this.summarized = (this.quote.summaries != null) && !ModelUtils.isEmpty(this.quote.summaries);
	this.draggedRowKey = null;
	if ((this.solutionGroups != null) && (this.solutionGroups.length > 0)) {
		this.selectedSolutionGroup = this.solutionGroups[0];
	}
}

QuoteEditorModel.prototype.updateQuote = function(/*QuoteVO*/ vo) {
	var newQuote = new QuoteModel(this, vo);
	
	ModelUtils.copyNullProperties(this.quote.record, newQuote.record);
	angular.forEach(newQuote.lineItems, function(newItem) {
		var item = this.quote.lineItemsByKey[newItem.key];
		if (item != null) {
			ModelUtils.copyNullProperties(item.record, newItem.record);
		}
	}, this);
	angular.forEach(newQuote.lineItemGroups, function(newGroup) {
		var grp = this.quote.groupsByKey[newGroup.key];
		if (grp != null) {
			ModelUtils.copyNullProperties(grp.record, newGroup.record);
		}
	}, this);
	
	this.quote = newQuote;
	this.quote.renumber();
	this.summarized = (this.quote.summaries != null) && !ModelUtils.isEmpty(this.quote.summaries);
	
	this.initQuoteSectionRows();
}

QuoteEditorModel.prototype.getLineFields = function(/*String*/ formFactor) {
	if ((formFactor != null) && (formFactor == 'tablet')) {
		return this.lineFieldsTablet;
	} else if ((formFactor != null) && (formFactor == 'phone')) {
		return this.lineFieldsPhone;
	}
	return this.lineFields;
}

QuoteEditorModel.prototype.getUnitOptions = function(/*Field*/ field) {
	if (field.name == QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD) {
		return this.additionalDiscountUnitOptions;
	} else if (field.name == QuoteLineModel.MARKUP_FIELD) {
		return this.markupUnitOptions;
	}
	return null;
}

QuoteEditorModel.prototype.initMetaData = function() {
	var prefix = this.developerPrefix;
	
	this.initFieldNames();
	
	var quoteMetaData = this.metaDataService.getMetaData(this.quoteObjectName);
	var groupMetaData = this.metaDataService.getMetaData(prefix + 'QuoteLineGroup__c');
	var lineMetaData = this.metaDataService.getMetaData(this.quoteLineObjectName);
	
	this.quoteNetAmountField = quoteMetaData.getField(prefix + 'NetAmount__c');
	if (groupMetaData != null) {
		this.groupNetTotalField = groupMetaData.getField(prefix + 'NetTotal__c');
	}
	this.subscriptionScopeField = angular.copy(lineMetaData.getField(prefix + 'SubscriptionScope__c'));
	this.subscriptionScopeField.required = true;
	
	this.quoteFields = [];
	angular.forEach(this.quoteFieldNames, function(name) {
		this.quoteFields.push( this.metaDataService.getMetaData(this.quoteObjectName).getField(name) );
	}, this);
	
	this.groupFields = [];
	angular.forEach(this.groupFieldNames, function(name) {
		var gfield = groupMetaData.getField(name);
		if (gfield == null) {
			// Field not available; probably because of security settings
			return;
		}
		if (gfield.name == QuoteLineGroupModel.DESCRIPTION_FIELD) {
			this.groupDescriptionField = gfield;
		}
		if ((gfield.name == QuoteLineGroupModel.QUOTE_PROCESS_FIELD) && (this.quoteProcesses != null)) {
			var values = [];
			angular.forEach(this.quoteProcesses, function(qprocess) {
				values.push({value:qprocess.Id,label:qprocess.Name});
			});
			gfield = new Field({name:name,label:gfield.label,updateable:gfield.updateable,type:'PICKLIST',picklistValues:values});
		}
		this.groupFields.push(gfield);
	}, this);
	this.groupDescriptionRendered = (this.groupDescriptionField != null);
	
	this.lineFields = [];
	this.calculatedLineFields = {};
	angular.forEach(this.lineFieldNames, function(name) {
		var field = this.metaDataService.getMetaData(this.quoteLineObjectName).getField(name);
		if (field == null) {
			// Field not available; probably because of security settings
			return;
		}
		this.lineFields.push(field);
		if (field.describe.calculated.toLowerCase() == 'true') {
			this.calculatedLineFields[field.name] = field;
		}
		var labelFieldName = field.describe.name.replace('__c', '').replace(prefix + '__', '') + 'ColumnLabel__c';
		if (this.quote.record[labelFieldName]) {
			field.label = this.quote.record[labelFieldName];
		}
		
		// Override field editability with values in the model; they may be different from FLS due to custom page plugin
		field.updateable = this.lineFieldEditability[field.name];
		
		// Convert Subscription Base to a picklist
		if (field.name == QuoteLineModel.SUBSCRIPTION_BASE_FIELD) {
			field.type = 'PICKLIST';
			field.required = true;
			field.picklistValues = this.subscriptionBaseOptions;
		}
		
		if (field.name == QuoteLineModel.QUANTITY_FIELD) {
			field.scale = this.settings.quantityScale;
			var pcCtrl = this.scope.controllerManager.lookup('ProductConfigurator');
			if (pcCtrl != null) {
				pcCtrl.scope.quantityScale = this.settings.quantityScale;
			}
		}
		
		if ((field.name == QuoteLineModel.LIST_PRICE_FIELD) ||
				(field.name == QuoteLineModel.REGULAR_PRICE_FIELD) ||
				(field.name == QuoteLineModel.SPECIAL_PRICE_FIELD) ||
				(field.name == QuoteLineModel.CUSTOMER_PRICE_FIELD) ||
				(field.name == QuoteLineModel.PARTNER_PRICE_FIELD) ||
				(field.name == QuoteLineModel.NET_PRICE_FIELD) ||
				(field.name == QuoteLineModel.UNIT_COST_FIELD)) {
			field.scale = this.settings.priceScale;
		}
		
		// Shown field flags
		if (field.name == QuoteLineModel.OPTIONAL_FIELD) {
			this.optionalFieldShown = true;
		} else if (field.name == QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD) {
			this.additionalDiscountFieldShown = true;
		}
	}, this);
	
	this.lineFieldsTablet = this.lineFields;
	if (this.lineFieldNamesTablet != null) {
		this.lineFieldsTablet = [];
		angular.forEach(this.lineFieldNamesTablet, function(name) {
			var field = this.metaDataService.getMetaData(this.quoteLineObjectName).getField(name);
			this.lineFieldsTablet.push(field);
		}, this);
	}
	
	this.lineFieldsPhone = this.lineFields;
	if (this.lineFieldNamesPhone != null) {
		this.lineFieldsPhone = [];
		angular.forEach(this.lineFieldNamesPhone, function(name) {
			var field = this.metaDataService.getMetaData(this.quoteLineObjectName).getField(name);
			this.lineFieldsPhone.push(field);
		}, this);
	}
	
	this.initQuoteSectionRows();
	
	var actions = this.customActions;
	this.customActions = [];
	angular.forEach(actions, function(action) {
		this.customActions.push(new CustomActionModel(action, this.metaDataService));
	}, this);
}

QuoteEditorModel.prototype.initFieldNames = function() {
	var prefix = this.developerPrefix;
	
	QuoteLineModel.PRICING_METHOD_FIELD = prefix + 'PricingMethod__c';
	QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD = prefix + 'AdditionalDiscount__c';
	QuoteLineModel.ADDITIONAL_DISCOUNT_RATE_FIELD = prefix + 'Discount__c';
	QuoteLineModel.ADDITIONAL_DISCOUNT_AMOUNT_FIELD = prefix + 'AdditionalDiscountAmount__c';
	QuoteLineModel.MARKUP_FIELD = prefix + 'Markup__c';
	QuoteLineModel.MARKUP_RATE_FIELD = prefix + 'MarkupRate__c';
	QuoteLineModel.MARKUP_AMOUNT_FIELD = prefix + 'MarkupAmount__c';
	QuoteLineModel.UNIT_COST_FIELD = prefix + 'UnitCost__c';
	QuoteLineModel.QUANTITY_FIELD = prefix + 'Quantity__c';
	QuoteLineModel.CUSTOMER_PRICE_FIELD = prefix + 'CustomerPrice__c';
	QuoteLineModel.REGULAR_PRICE_FIELD = prefix + 'RegularPrice__c';
	QuoteLineModel.SPECIAL_PRICE_FIELD = prefix + 'SpecialPrice__c';
	QuoteLineModel.PARTNER_PRICE_FIELD = prefix + 'PartnerPrice__c';
	QuoteLineModel.NET_PRICE_FIELD = prefix + 'NetPrice__c';
	QuoteLineModel.COMPONENT_DISCOUNTED_BY_PACKAGE_FIELD = prefix + 'ComponentDiscountedByPackage__c';
	QuoteLineModel.NON_DISCOUNTABLE_FIELD = prefix + 'NonDiscountable__c';
	QuoteLineModel.SUBSCRIPTION_PRICING_FIELD = prefix + 'SubscriptionPricing__c';
	QuoteLineModel.COMPONENT_SUBSCRIPTION_SCOPE_FIELD = prefix + 'ComponentSubscriptionScope__c';
	QuoteLineModel.COMPONENT_VISIBILITY_FIELD = prefix + 'ComponentVisibility__c';
	QuoteLineModel.SUBSCRIBED_ASSET_IDS_FIELD = prefix + 'SubscribedAssetIds__c';
	QuoteLineModel.START_DATE_FIELD = prefix + 'StartDate__c';
	QuoteLineModel.END_DATE_FIELD = prefix + 'EndDate__c';
	QuoteLineModel.SUBSCRIPTION_TERM_FIELD = prefix + 'SubscriptionTerm__c';
	QuoteLineModel.OPTIONAL_FIELD = prefix + 'Optional__c';
	QuoteLineModel.BUNDLE_FIELD = prefix + 'Bundle__c';
	QuoteLineModel.BUNDLED_FIELD = prefix + 'Bundled__c';
	QuoteLineModel.NUMBER_FIELD = prefix + 'Number__c';
	QuoteLineModel.OPTION_TYPE_FIELD = prefix + 'OptionType__c';
	QuoteLineModel.BUNDLED_QUANTITY_FIELD = prefix + 'BundledQuantity__c';
	QuoteLineModel.SUBSCRIPTION_SCOPE_FIELD = prefix + 'SubscriptionScope__c';
	QuoteLineModel.PRICE_EDITABLE_FIELD = prefix + 'PriceEditable__c';
	QuoteLineModel.COST_EDITABLE_FIELD = prefix + 'CostEditable__c';
	QuoteLineModel.LIST_PRICE_FIELD = prefix + 'ListPrice__c';
	QuoteLineModel.SUBSCRIPTION_BASE_FIELD = prefix + 'SubscriptionBase__c';
	QuoteLineModel.PRODUCT_NAME_FIELD = prefix + 'ProductName__c';
	QuoteLineModel.RENEWED_ASSET_ID_FIELD = prefix + 'RenewedAsset__c';
	QuoteLineGroupModel.DESCRIPTION_FIELD = prefix + 'Description__c';
	QuoteLineGroupModel.CUSTOMER_TOTAL_FIELD = prefix + 'CustomerTotal__c';
	QuoteLineGroupModel.NET_TOTAL_FIELD = prefix + 'NetTotal__c';
	QuoteLineGroupModel.OPTIONAL_FIELD = prefix + 'Optional__c';
	QuoteLineGroupModel.QUOTE_PROCESS_FIELD = prefix + 'QuoteProcess__c';
	QuoteLineGroupModel.SOLUTION_GROUP_ID_FIELD = prefix + 'SolutionGroup__c';
	QuoteLineGroupModel.NUMBER_FIELD = prefix + 'Number__c';
	QuoteModel.QUOTE_PROCESS_ID_FIELD = prefix + 'QuoteProcessId__c';
	QuoteModel.PRICEBOOK_ID_FIELD = prefix + 'PricebookId__c';
	QuoteModel.OPPORTUNITY_ID_FIELD = prefix + 'Opportunity__c';
	QuoteModel.OPPORTUNITY_FIELD = prefix + 'Opportunity__r';
	QuoteModel.GROUP_LINE_ITEMS_FIELD = prefix + 'LineItemsGrouped__c';
}

QuoteEditorModel.prototype.initQuoteSectionRows = function() {
	var maxFieldsPerRow = Controller.isMobileContext() ? 1 : 3;
	this.quoteSectionRows = [];
	var sectionRow = [];
	angular.forEach(this.quoteFields, function(field) {
		sectionRow.push(field);
		if (sectionRow.length == maxFieldsPerRow) {
			this.quoteSectionRows.push(sectionRow);
			sectionRow = [];
		}
	}, this);
	if (sectionRow.length > 0) {
		this.quoteSectionRows.push(sectionRow);
	}
}

QuoteEditorModel.prototype.getQuoteTotal = function() {
	return (this.quote.applyAdditionalDiscountLast) ? this.quote.customerTotal : this.quote.netTotal;
}

QuoteEditorModel.prototype.getLineColumnCount = function(/*String*/ formFactor) {
	var count = this.getLineFields(formFactor).length;
    if (this.isSubscriptionScopeShown() && !Controller.isMobileContext()) {
        count++;
    }
    if (this.settings.multiLineDeleteEnabled && !Controller.isMobileContext()) {
        count++;
    }
    return count;
}

QuoteEditorModel.prototype.optionalFieldDisplayed = function() {
}

QuoteEditorModel.prototype.isSubscriptionScopeShown = function() {
	if (this.quote.grouped == true) {
		var result = false;
		angular.forEach(this.quote.lineItems, function(item) {
			result = result || item.subscriptionScopeEditable;
		}, this);
		return result;
	}
	return false;
}

QuoteEditorModel.prototype.copyQuote = function(/*Boolean*/ includeDetail) {
	// Update IDs of lookup fields stored in hidden fields into the mdoel.
	// Since they are set by SFDC native popup window there is no way to do this in real time
	this.scope.$broadcast('updateLookups');
	var result = this.quote.createCopy();
	if (includeDetail) {
		if (this.quote.grouped) {
			result.lineItemGroups = [];
			for (var i=0;i<this.quote.lineItemGroups.length;i++) {
				var groupModel = this.quote.lineItemGroups[i];
				result.lineItemGroups.push(groupModel.createCopy());
			}
		}
		result.lineItems = [];
		for (var i=0;i<this.quote.lineItems.length;i++) {
			var line = this.quote.lineItems[i];
			result.lineItems.push(line.createCopy());
		}
	}
	return result;
}



function ProductSelectionModel(/*ProductSelectionModel*/ data) {
	ModelUtils.copyProperties(data, this);
}

ProductSelectionModel.prototype.updateConfigurations = function(/*ProductVO[]*/ configuredProducts) {
	var configsByProductId = {};
	jQuery.each(configuredProducts, function(idx, product) {
		if (product.configuration != null) {
			configsByProductId[product.configuration.configuredProductId] = product.configuration;
		}
	});
	
	jQuery.each(this.selectedProducts, function(idx, product) {
		var productId = product.record.Id;
		if (configsByProductId[productId] != null) {
			product.configuration = configsByProductId[productId].createVO();
			product.configuration.configured = true;
		}
	});
}

ProductSelectionModel.prototype.setUpgradedAssets = function(/*String*/ productId, /*String[]*/ assetIds) {
	jQuery.each(this.selectedProducts, function(idx, product) {
		var productId = product.record.Id;
		if (product.record.Id == productId) {
			product.upgradedAssetIds = assetIds;
		}
	});
}

ProductSelectionModel.prototype.createCopy = function() {
	var result = angular.copy(this);
	result.selectedProducts = [];
	angular.forEach(this.selectedProducts, function(product) {
		if ((product.upgradedAssetIds != null) && (product.upgradedAssetIds.length > 0)) {
			// Blow out multiple upgraded assets into a separate product/asset pair.
			angular.forEach(product.upgradedAssetIds, function(assetId) {
				var clonedProduct = angular.copy(product);
				clonedProduct.upgradedAssetId = assetId;
				result.selectedProducts.push(clonedProduct);
			});
		} else {
			result.selectedProducts.push(product);
		}
	}, this);
	return result;
}



function QuoteModel(/*QuoteEditorModel*/ editorModel, /*Object*/ data) {
	ModelUtils.copyProperties(data, this);
	this.editorModel = editorModel;
	var qmodel = this;
	
	this.groupsByKey = {};
	this.lineItemGroups = [];
	this.grouped = data.record[QuoteModel.GROUP_LINE_ITEMS_FIELD];
	if (this.grouped) {
		angular.forEach(data.lineItemGroups, function(itemGroup) {
			var groupModel = new QuoteLineGroupModel(qmodel, itemGroup);
			this.groupsByKey[itemGroup.key] = groupModel;
			this.lineItemGroups.push(groupModel);
			groupModel.summaryLine = new QuoteSummaryModel(qmodel, {record:groupModel.summaries});
		}, this);
	} else {
		var virtualGroup = new QuoteLineGroupModel(qmodel, {record:{}});
		this.lineItemGroups = [virtualGroup];
		virtualGroup.summaryLine = new QuoteSummaryModel(qmodel, {record:qmodel.summaries});
		this.groupsByKey[null] = virtualGroup;
	}
	
	this.lineItemsByKey = {};
	this.lineItems = [];
	angular.forEach(data.lineItems, function(line) {
		var itemGroup = this.groupsByKey[line.parentGroupKey];
		var item = new QuoteLineModel(qmodel, itemGroup, line)
		this.lineItemsByKey[item.key] = item;
		this.lineItems.push(item);
		if (itemGroup != null) {
			itemGroup.lineItems.push(item);
		}
	}, this);
}

QuoteModel.prototype.getId = function() {
	return this.record['Id'];
}

QuoteModel.prototype.getPricebookId = function() {
	if (this.record[QuoteModel.PRICEBOOK_ID_FIELD]) {
		return this.record[QuoteModel.PRICEBOOK_ID_FIELD];
	}
	if (this.record[QuoteModel.OPPORTUNITY_ID_FIELD]) {
		return this.record[QuoteModel.OPPORTUNITY_FIELD].Pricebook2Id;
	}
	return null;
}

QuoteModel.prototype.getOpportunityId = function() {
	return this.record[QuoteModel.OPPORTUNITY_ID_FIELD];
}

QuoteModel.prototype.getId = function() {
	return this.record['Id'];
}

QuoteModel.prototype.createCopy = function() {
	var result = {nextKey:this.nextKey};
	result.contractedAccountId = this.contractedAccountId;
	result.lineSortField = this.lineSortField;
	result.applyAdditionalDiscountLast = this.applyAdditionalDiscountLast;
	result.applyPartnerDiscountFirst = this.applyPartnerDiscountFirst;
	result.channelDiscountsOffList = this.channelDiscountsOffList;
	result.record = this.record;
	angular.forEach(this.editorModel.quoteFields, function(field) {
		if (field.isRenderedAsLookup()) {
			var ref = this.record[field.describe.relationshipName];
			result.record[field.name] = (ref == null) ? null : ref.Id;
			delete result.record[field.describe.relationshipName];
		}
	}, this);
	return result;
}

QuoteModel.prototype.addGroup = function(/*SolutionGroup__c*/ solutionGroup) {
	this.nextKey++;
	var itemGroup = new QuoteLineGroupModel(this, {key:this.nextKey,record:{}});
	if (solutionGroup != null) {
		itemGroup.record['Name'] = solutionGroup['Name'];
		itemGroup.record[QuoteLineGroupModel.DESCRIPTION_FIELD] = solutionGroup[QuoteLineGroupModel.DESCRIPTION_FIELD];
		itemGroup.record[QuoteLineGroupModel.SOLUTION_GROUP_ID_FIELD] = solutionGroup['Id'];
	}
	this.lineItemGroups.push(itemGroup);
	this.editorModel.quote.renumber();
	this.groupsByKey[itemGroup.key] = itemGroup;
	return itemGroup;
}

QuoteModel.prototype.getInputId = function(/*Field*/ field) {
	return ('q_' + field.name);
}

QuoteModel.prototype.moveLine = function(/*Integer*/ srcKey, /*Integer*/ targetKey) {
	var srcLine = this.lineItemsByKey[srcKey];
	if (srcLine != null) {
		var targetLine = this.lineItemsByKey[targetKey];
		var targetGroup = this.groupsByKey[targetKey];
		if (targetLine != null) {
			var srcLineIdx = this.lineItems.indexOf(srcLine);
			if (srcLineIdx < 0) {
				return;
			}
			this.lineItems.splice(srcLineIdx, 1);
			
			var targetLineIdx = this.lineItems.indexOf(targetLine);
			if (targetLineIdx < 0) {
				return;
			} else {
				if (targetLineIdx >= srcLineIdx) {
					this.lineItems.splice(targetLineIdx + 1, 0, srcLine);
				} else {
					this.lineItems.splice(targetLineIdx, 0, srcLine);
				}
			}
			srcLine.parentGroupKey = targetLine.parentGroupKey;
		} else if (targetGroup != null) {
			srcLine.parentGroupKey = targetGroup.key;
		}
		
		angular.forEach(this.lineItemGroups, function(itemGroup) {
			itemGroup.lineItems = [];
		}, this);
		
		angular.forEach(this.lineItems, function(item) {
			var itemGroup = this.groupsByKey[item.parentGroupKey];
			if (itemGroup != null) {
				itemGroup.lineItems.push(item);
			}
		}, this);
		
		this.renumber();
	}
}

QuoteModel.prototype.renumber = function() {
	var idx = 1;
	var items = [];
	angular.forEach(this.lineItemGroups, function(itemGroup) {
		itemGroup.record[QuoteLineGroupModel.NUMBER_FIELD] = idx;
		idx++;
		angular.forEach(itemGroup.lineItems, function(item) {
			items.push(item);
		});
	});
	
	idx = 1;
	var invisibleIdx = 3000;
	angular.forEach(items, function(item) {
		if (item.isVisibleInEditor()) {
			item.record[QuoteLineModel.NUMBER_FIELD] = idx;
			idx++;
		} else {
			item.record[QuoteLineModel.NUMBER_FIELD] = invisibleIdx;
			invisibleIdx++;
		}
	}, this);
}

QuoteModel.prototype.getSelectedLineKeys = function() {
	var result = [];
	angular.forEach(this.lineItems, function(item) {
		if (item.selected) {
			result.push(item.key);
		}
	}, this);
	return result;
}

QuoteModel.prototype.clearLineSelections = function() {
	angular.forEach(scope.editorModel.lineItems, function(item) {
		if (item.selected) {
			item.selected = false;
		}
	}, this);
}


function QuoteLineGroupModel(/*QuoteModel*/ quote, /*Object*/ data) {
	this.lineItems = new Array();
	this.quote = quote;
	ModelUtils.copyProperties(data, this);
	//ModelUtils.convertValues(this.quote.editorModel.groupFields, this.record);
}

QuoteLineGroupModel.prototype.getVisibleLineItems = function() {
	var result = [];
	angular.forEach(this.lineItems, function(lineItem) {
		if (lineItem.isVisibleInEditor()) {
			result.push(lineItem);
		}
	}, this);
	return result;
}

QuoteLineGroupModel.prototype.hasLineItems = function() {
	return (this.lineItems.length > 0);
}

QuoteLineGroupModel.prototype.getTotal = function() {
	if (this.quote.grouped) {
		return (this.quote.applyAdditionalDiscountLast) ? this.record[QuoteLineGroupModel.CUSTOMER_TOTAL_FIELD] : this.record[QuoteLineGroupModel.NET_TOTAL_FIELD];
	} else {
		return (this.quote.applyAdditionalDiscountLast) ? this.quote.customerTotal : this.quote.netTotal;
	}
}

QuoteLineGroupModel.prototype.createCopy = function() {
	var result = {record:this.record,key:this.key};
	angular.forEach(this.quote.editorModel.groupFields, function(field) {
		if (field.isRenderedAsLookup()) {
			var ref = this.record[field.describe.relationshipName];
			result.record[field.name] = (ref == null) ? null : ref.Id;
			delete result.record[field.describe.relationshipName];
		}
	}, this);
	return result;
}

QuoteLineGroupModel.prototype.getInputId = function(/*Field*/ field) {
	return ('g' + this.key + '_' + field.name);
}

QuoteLineGroupModel.prototype.updateLineOptional = function(/*Boolean*/ value) {
	angular.forEach(this.lineItems, function(item) {
		item.record[QuoteLineModel.OPTIONAL_FIELD] = value;
	}, this);
}

QuoteLineGroupModel.prototype.isOptional = function() {
	return this.record[QuoteLineGroupModel.OPTIONAL_FIELD];
}



function QuoteLineModel(/*QuoteModel*/ quote, /*QuoteLineGroupModel*/ group, /*Object*/ data) {
	ModelUtils.copyProperties(data, this);
	this.line = null;
	this.calculatedValues = null;
	// This needs to be after copyProperties
	this.quote = quote;
	this.group = group;
	
	// Default pricing method
	if (this.record[QuoteLineModel.PRICING_METHOD_FIELD] == null) {
		this.record[QuoteLineModel.PRICING_METHOD_FIELD] = 'List';
	}
	
	var optionType = this.record[QuoteLineModel.OPTION_TYPE_FIELD];
	this.renewedAssetId = this.record[QuoteLineModel.RENEWED_ASSET_ID_FIELD];
	this.component = (this.parentItemKey != null);
	this.subscription = (this.record[QuoteLineModel.SUBSCRIPTION_PRICING_FIELD] != null);
	this.dynamicSubscription = (this.record[QuoteLineModel.SUBSCRIPTION_PRICING_FIELD] == 'Percent Of Total');
	this.subscriptionScopeEditable = this.dynamicSubscription && (this.record[QuoteLineModel.COMPONENT_SUBSCRIPTION_SCOPE_FIELD] == null) && (this.record[QuoteLineModel.SUBSCRIBED_ASSET_IDS_FIELD] == null);
	this.rootPackage = ModelUtils.isBlank(this.parentItemKey);
	this.quantityEditable = ((this.record[QuoteLineModel.BUNDLED_QUANTITY_FIELD] == null) || !this.component) && (this.renewedAssetId == null);
	this.costEditable = (this.record[QuoteLineModel.COST_EDITABLE_FIELD] == true);
	this.unitCostEditable = this.costEditable && !this.bundled && !this.dynamicSubscription;
	this.pricingMethodList = (this.record[QuoteLineModel.PRICING_METHOD_FIELD] == 'List');
	this.pricingMethodCustom = (this.record[QuoteLineModel.PRICING_METHOD_FIELD] == 'Custom');
	this.pricingMethodCost = (this.record[QuoteLineModel.PRICING_METHOD_FIELD] == 'Cost');
	this.bundled = (this.record[QuoteLineModel.BUNDLED_FIELD] == true);
	this.bundle = (this.record[QuoteLineModel.BUNDLE_FIELD] == true);
	this.nonDiscountable = (this.record[QuoteLineModel.NON_DISCOUNTABLE_FIELD] == true);
	this.nonPartnerDiscountable = (this.record[QuoteLineModel.NON_PARTNER_DISCOUNTABLE_FIELD] == true);
	this.componentDiscountedByPackage = (this.record[QuoteLineModel.COMPONENT_DISCOUNTED_BY_PACKAGE_FIELD] == true);
	this.discountable = !this.bundled && !this.nonDiscountable && !this.pricingMethodCustom && !this.componentDiscountedByPackage;
	this.removable = (this.parentItemKey == null);
	this.rootPackage = this.bundle && (this.parentItemKey == null);
	this.configurable = this.rootPackage && !this.reconfigurationDisabled && (this.configurationType != 'Disabled') && ((this.configurationEvent == null) || (this.configurationEvent == 'Always') || (this.configurationEvent == 'Edit'));
	this.listPriceEditable = this.record[QuoteLineModel.PRICE_EDITABLE_FIELD] && !this.bundled && !this.dynamicSubscription && this.pricingMethodList;
	
	this.units = {};
	// Default additional discount unit
	this.units[QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD] = this.quote.editorModel.defaultAdditionalDiscountUnit;
	if (this.record[QuoteLineModel.ADDITIONAL_DISCOUNT_AMOUNT_FIELD] != null) {
		this.units[QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD] = 'Amount';
	} else if (this.record[QuoteLineModel.ADDITIONAL_DISCOUNT_RATE_FIELD] != null) {
		this.units[QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD] = 'Percent';
	}
	
	// Default markup unit
	this.units[QuoteLineModel.MARKUP_FIELD] = this.quote.editorModel.defaultMarkupUnit;
	if (this.record[QuoteLineModel.MARKUP_AMOUNT_FIELD] != null) {
		this.units[QuoteLineModel.MARKUP_FIELD] = 'Amount';
	} else if (this.record[QuoteLineModel.MARKUP_RATE_FIELD] != null) {
		this.units[QuoteLineModel.MARKUP_FIELD] = 'Percent';
	}
	
	
	//pricingMethodDisabled = lineVO.isDynamicSubscription() || lineVO.isBundled() || !lineVO.isPricingMethodEditable();
}

QuoteLineModel.prototype.resetAdditionalDiscount = function() {
	this.record[QuoteLineModel.ADDITIONAL_DISCOUNT_RATE_FIELD] = null;
	this.record[QuoteLineModel.ADDITIONAL_DISCOUNT_AMOUNT_FIELD] = null;
	this.units[QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD] = this.quote.editorModel.defaultAdditionalDiscountUnit;
}

QuoteLineModel.prototype.isVisibleInEditor = function() {
	var visible = (this.componentVisibility == null) || (this.componentVisibility == 'Always') || (this.componentVisibility == 'Editor Only');
	if (visible && (this.renewedAssetId != null) && this.quote.editorModel.settings.renewedAssetsHiddenWhenEditing) {
		return false;
	}
	return visible;
}

QuoteLineModel.prototype.getProductName = function() {
	return this.record[QuoteLineModel.PRODUCT_NAME_FIELD];
}

QuoteLineModel.prototype.getNumber = function() {
	return this.record[QuoteLineModel.NUMBER_FIELD];
}

QuoteLineModel.prototype.createCopy = function() {
	var result = new Object();
	result.record = new Object();
	// Copy the attributes property of SObject
	result.record.attributes = this.record.attributes;
	result.key = this.key;
	result.parentGroupKey = this.parentGroupKey;
	result.parentItemKey = this.parentItemKey;
	result.componentVisibility = this.componentVisibility;
	angular.forEach(this.record, function(value, property) {
		if (this.quote.editorModel.calculatedLineFields[property] == null) {
			result.record[property] = value;
		}
	}, this);
	angular.forEach(this.quote.editorModel.lineFields, function(field) {
		if (field.isRenderedAsLookup()) {
			var ref = this.record[field.describe.relationshipName];
			result.record[field.name] = (ref == null) ? null : ref.Id;
			delete result.record[field.describe.relationshipName];
		}
	}, this);
	return result;
}

QuoteLineModel.prototype.getRowId = function(/*String*/ fieldName) {
	return (this.rowId != null) ? this.rowId : this.key;
}

QuoteLineModel.prototype.getInputId = function(/*Field*/ field) {
	return (field.name + '_' + this.key);
}

QuoteLineModel.prototype.isDisabled = function(/*Field*/ field) {
	if ((field.name == QuoteLineModel.OPTIONAL_FIELD) && (this.group != null) && this.group.isOptional()) {
		return true;
	}
	return false;
}

QuoteLineModel.prototype.isIncluded = function(/*Field*/ field) {
	return this.bundled && ((field.name == QuoteLineModel.LIST_PRICE_FIELD) || (field.name == QuoteLineModel.UNIT_COST_FIELD));
}

QuoteLineModel.prototype.isEditable = function(/*Field*/ field) {
	if (field.name == QuoteLineModel.QUANTITY_FIELD) {
		return field.updateable && this.quantityEditable;
	} else if (field.name == QuoteLineModel.LIST_PRICE_FIELD) {
		return field.updateable && this.listPriceEditable;
	} else if (field.name == QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD) {
		return this.discountable && !this.componentDiscountedByPackage;
	} else if (field.name == QuoteLineModel.UNIT_COST_FIELD) {
		return field.updateable && this.unitCostEditable;
	} else if (field.name == QuoteLineModel.CUSTOMER_PRICE_FIELD) {
		return field.updateable && this.pricingMethodCustom;
	} else if (field.name == QuoteLineModel.PRICING_METHOD_FIELD) {
		return field.updateable && !this.pricingMethodDisabled;
	} else if (field.name == QuoteLineModel.MARKUP_FIELD) {
		return !this.bundled && this.pricingMethodCost;
	} else if (field.name == QuoteLineModel.NET_PRICE_FIELD) {
		return false;
	} else if (field.name == QuoteLineModel.PARTNER_PRICE_FIELD) {
		return false;
	} else if (field.name == QuoteLineModel.DESCRIPTION_FIELD) {
		return false;
	} else if (field.name == QuoteLineModel.PACKAGE_PRODUCT_CODE_FIELD) {
		return false;
	} else if (field.name == QuoteLineModel.PRORATED_LIST_PRICE_FIELD) {
		return false;
	} else if (field.name == QuoteLineModel.REGULAR_PRICE_FIELD) {
		return false;
	}
	return field.updateable;
}

QuoteLineModel.prototype.isFieldRendered = function(/*Field*/ field) {
	if (!this.subscription) {
		if ((field.name == QuoteLineModel.START_DATE_FIELD) || 
				(field.name == QuoteLineModel.END_DATE_FIELD) || 
				(field.name == QuoteLineModel.SUBSCRIPTION_TERM_FIELD)) {
			return false;
		}
	}
	
	if (!this.dynamicSubscription && (field.name == QuoteLineModel.SUBSCRIPTION_BASE_FIELD)) {
		return false;
	}
	
	if (!this.discountable && (field.name == QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD)) {
		return false;
	}
	
	if (!this.pricingMethodCost && (field.name == QuoteLineModel.MARKUP_FIELD)) {
		return false;
	}
	
	if (this.nonPartnerDiscountable && (field.name == QuoteLineModel.PARTNER_DISCOUNT_FIELD)) {
		return false;
	}
	
	return true;
}

QuoteLineModel.prototype.isUnitRendered = function(/*Field*/ field) {
	if ((field.name == QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD) && this.discountable) {
		return true;
	} else if (field.name == QuoteLineModel.MARKUP_FIELD) {
		return true;
	}
	return false;
}

QuoteLineModel.prototype.getScale = function(/*Field*/ field) {
	if ((field.name == QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD) && (this.units[field.name] != 'Amount')) {
		return null;
	}
	return field.scale;
}

QuoteLineModel.prototype.mapPropertyName = function(/*Field*/ field) {
	if (field.name == QuoteLineModel.MARKUP_FIELD) {
		if (this.units[field.name] == 'Amount') {
			return QuoteLineModel.MARKUP_AMOUNT_FIELD;
		} else {
			return QuoteLineModel.MARKUP_RATE_FIELD;
		}
	} else if (field.name == QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD) {
		if (this.units[field.name] == 'Amount') {
			return QuoteLineModel.ADDITIONAL_DISCOUNT_AMOUNT_FIELD;
		} else {
			return QuoteLineModel.ADDITIONAL_DISCOUNT_RATE_FIELD;
		}
	}
	return field.getValueProperty()
}

QuoteLineModel.prototype.changeAdditionalDiscountUnit = function() {
	var price = this.record[QuoteLineModel.REGULAR_PRICE_FIELD];
	if (this.units[QuoteLineModel.ADDITIONAL_DISCOUNT_FIELD] == 'Percent') {
		var discount = this.record[QuoteLineModel.ADDITIONAL_DISCOUNT_AMOUNT_FIELD];
		discount = (discount == null) ? 0 : discount;
		this.record[QuoteLineModel.ADDITIONAL_DISCOUNT_RATE_FIELD] = (price != null) ? (discount / price * 100) : null;
		this.record[QuoteLineModel.ADDITIONAL_DISCOUNT_AMOUNT_FIELD] = null;
	} else {
		var rate = this.record[QuoteLineModel.ADDITIONAL_DISCOUNT_RATE_FIELD];
		rate = (rate == null) ? 0 : rate;
		this.record[QuoteLineModel.ADDITIONAL_DISCOUNT_AMOUNT_FIELD] = (price != null) ? (price * (rate / 100)) : null;
		this.record[QuoteLineModel.ADDITIONAL_DISCOUNT_RATE_FIELD] = null;
	}
}

QuoteLineModel.prototype.changeMarkupUnit = function(/*QuoteLineModel*/ line) {
	var cost = line.vales[QuoteLineModel.UNIT_COST_FIELD];
	if (this.units[QuoteLineModel.MARKUP_FIELD] == 'Percent') {
		var markup = this.values[QuoteLineModel.MARKUP_AMOUNT_FIELD];
		if (markup == null) {
			markup = 0;
		}
		this.values[QuoteLineModel.MARKUP_RATE_FIELD] = (cost != null) ? (markup / cost * 100) : null;
		this.values[QuoteLineModel.MARKUP_AMOUNT_FIELD] = null;
	} else {
		var markup = line.values[QuoteLineModel.MARKUP_RATE_FIELD];
		if (markup == null) {
			markup = 0;
		}
		this.values[QuoteLineModel.MARKUP_AMOUNT_FIELD] = (cost != null) ? (cost * (markup / 100)) : null;
		this.values[QuoteLineModel.MARKUP_RATE_FIELD] = null;
	}
}

QuoteLineModel.prototype.getIndentationMargin = function(/*Field*/ field){
	var scope = this;
	var prefix = this.quote.editorModel.developerPrefix;
	if (this.quote.editorModel.settings.productHierarchyVisualized) {
		if(field.name === prefix + 'ProductCode__c' || field.name === prefix + 'ProductName__c') {
			return 20 * this.record[prefix + 'OptionLevel__c'];
		}
	} else {
		return 0;
	}
}



function QuoteSummaryModel(/*QuoteModel*/ quote, /*Object*/ data) {
	this.values = new Object();
	ModelUtils.copyProperties(data, this);
	// This needs to be after copyProperties
	this.quote = quote;
}

QuoteSummaryModel.prototype.getInputId = function(/*Field*/ field) {
	return (field.name + '_' + this.key);
}

QuoteSummaryModel.prototype.isEditable = function(/*Field*/ field) {
	return false;
}

QuoteSummaryModel.prototype.isFieldRendered = function(/*Field*/ field) {
	if (this.record != null) {
		var value = this.record[this.mapPropertyName(field)];
		return ((value != undefined) && (value != null));
	}
	return false;
}

QuoteSummaryModel.prototype.mapPropertyName = function(/*Field*/ field) {
	return field.name.toLowerCase();
}
