<?xml version="1.0"?><!DOCTYPE pdf PUBLIC "-//big.faceless.org//report" "report-1.1.dtd">
<#-- Assign the currency symbol -->
<#if record.currency == "USD" || record.currency == "American Dollar" >
	<#assign currencySymbol = "$">
<#elseif record.currency == "GBP">
	<#assign currencySymbol = "£">
<#elseif record.currency == "CAD" || record.currency == "Canadian Dollar" >
	<#assign currencySymbol = "$">
<#elseif record.currency == "EUR" || record.currency == "EURO" >>
	<#assign currencySymbol = "€">
<#else>
	<#assign currencySymbol = "$">
</#if>

<#-- Computation of footer height -->
<#assign footerHeight = 78>
<#if subsidiary.custrecord_alf_share_capital?length != 0 || subsidiary.custrecord_alf_sic_code?length != 0>
	<#assign footerHeight = footerHeight + 13>
</#if>
<#if subsidiary.custrecord_alf_managing_director?length != 0>
	<#assign footerHeight = footerHeight + 13>
</#if>
<#if subsidiary.custrecord_alf_other_legal_info?length != 0>
	<#assign footerHeight = footerHeight + 13>
</#if>
<#assign footerHeight = footerHeight?string + "pt">

<#-- Format String to Number -->
<#function formattedStringToNumber s>
	<#local tmpstr = s?replace('[^\\.,٬0-9]','','r')?replace('[,٬]','.','r')>
	<#if tmpstr?has_content>
		<#if tmpstr?index_of(".") == -1>
			<#return tmpstr?number>
		<#else>
			<#return (tmpstr?keep_before_last(".")?replace('[.]', '', 'r') + "." + tmpstr?keep_after_last("."))?number>
		</#if>
	<#else>
		<#return 0>
	</#if>
</#function>

<#-- Check if atleast one line item has Tax applied-->
<#function taxesOnLines rec>
	<#list rec.item as itm>
		<#if itm.taxamount?has_content || itm.tax1amt?has_content || itm.taxrate1?has_content || isTrue(itm.istaxable)>
			<#return true>
		</#if>
	</#list>
	<#return false>
</#function>

<#-- Checking if value is True -->
<#function isTrue x>
	<#return (x?is_boolean && x) || (x?is_string && x == "T")>
</#function>

<#-- Checking if value is not zero -->
<#function notZero x>
	<#return x?has_content && x != 0>
</#function>

<#-- Rounding to X decimal places -->
<#function roundNum num decimalPlaces>
	<#if num?is_number>
		<#if (decimalPlaces > 0 )>
			<#assign num2 = num />
			<#assign decPlaces = 1 />
			<#assign decPlacesDivide = 1 />
			<#list 1..decimalPlaces as count>
				<#assign decPlaces = decPlaces * 10/>
				<#assign decPlacesDivide = decPlacesDivide * 0.1/>
			</#list>
		</#if>
		<#assign roundedNum = (((num2*decPlaces)?round) * decPlacesDivide ) />
		<#return roundedNum>
	<#else>
		<#return num >
	</#if>
</#function>

<#-- Format to number -->
<#function num x>
	<#if x == 0>
		<#return ''>
	</#if>
	<#local result = nsformat_rate(x)?replace("^.*?((\\d.*\\d)|(\\d)).*$","$1","r")>
	<#local result = result?remove_ending('.00')?remove_ending(',00')>
	<#return result>
</#function>

<#-- Format to amount -->
<#function amt x options={}>
	<#if x?string == "">
		<#return x>
	<#elseif x?string?contains("%")>
		<#return nsformat_currency(x * 100)?string?replace(currencySymbol,"")?replace('[^\\.,٬٫0-9\\-\\(\\)\\u00A0]','','r') + "%">
	</#if>
	<#if options.round!true>
		<#local x = roundNum(x, 2)>
	</#if>
	<#return nsformat_currency(x)?string?replace(currencySymbol,"")?replace('[^\\.,٬٫0-9\\-\\(\\)\\u00A0]','','r')>
</#function>

<#-- Remove trailing zeroes -->
<#function removeTrailingZeroes x >
	<#local x = amt(x)>
	<#if x?string?contains("%")>
		<#local x = x?remove_ending("%")>
	</#if>
	<#if x?string?index_of(".") gt 0 >
		<#local index = x?string?index_of(".")>
	<#elseif x?string?index_of(",") gt 0>
		<#local index = x?string?index_of(",")>
	<#elseif x?string?index_of("٬") gt 0>
		<#local index = x?string?index_of("٬")>
	<#else>
		<#local index = x?string?index_of("٫")>
	</#if>
	<#if index gt 0>
		<#list (index..(x?string?length-1))as i>
			<#local x = x?remove_ending("0")>
		</#list>
	</#if>
	<#local x = x?remove_ending(".")>
	<#local x = x?remove_ending(",")>
	<#local x = x?remove_ending("٬")>
	<#local x = x?remove_ending("٫")>
	<#return x>
</#function>

<#-- Keep After # -->
<#function keepAfterHash str>
	<#return str?keep_after("#")>
</#function>

<#-- Get item tax rate -->
<#function getItemTaxRate item rec>
	<#if item.taxrate?has_content>
		<#return item.taxrate>
	<#elseif item.taxrate2?has_content>
		<#return (item.taxrate1 + item.taxrate2) * 100>
	<#elseif item.taxrate1?has_content>
		<#return item.taxrate1>
	<#elseif isTrue(item.istaxable)>
		<#return rec.taxrate>
	<#else>
		<#return 0>
	</#if>
</#function>

<#--Function that computes VAT Summary table for both legacy and SuiteTax-->
<#function computeVATsummary list rec>
	<#local result=[]>
	<#local processed_tax_rates=[]>

	<#-- condition to check if its legacy account-->
	<#if !record.taxsummary?has_content>

		<#--Invoice discount-->
		<#if notZero(record.discounttotal)>
			<#list list as item>
				<#local itemtaxrate = getItemTaxRate(item, rec)>
				<#if itemtaxrate gte 1>
					<#local itemtaxratenmr = itemtaxrate / 100>
				<#else>
					<#local itemtaxratenmr = itemtaxrate>
				</#if>

				<#if itemtaxrate?has_content>
					<#local discount_ratio = item.amount / record.subtotal>
					<#local discount_for_item = {
						"taxrate": itemtaxrate?string,
						"amount": discount_ratio * record.discounttotal,
						"taxamount": discount_ratio * itemtaxratenmr * record.discounttotal
						}>
					<#local list = list + [discount_for_item]>
				</#if>
			</#list>
	</#if>
	<#--Shipping-->
	<#local shippingcost = record.shippingcost>
	<#if notZero(record.handlingcost)><#local shippingcost = shippingcost - record.handlingcost></#if>
	<#if notZero(shippingcost)>
		<#if record.shippingtax2rate?has_content>
			<#local shippingrate = record.shippingtax1rate?number + record.shippingtax2rate?number>
		<#elseif record.shippingtax1rate?has_content>
			<#local shippingrate = record.shippingtax1rate>
		<#elseif record.taxrate?has_content && isTrue(record.shipping_btaxable)>
			<#local shippingrate = record.taxrate>
		<#else>
			<#local shippingrate = 0>
		</#if>
		<#local shipping = {
			"taxrate": shippingrate?string,
			"amount": shippingcost,
			"taxamount": (formattedStringToNumber(shippingrate) / 100) * shippingcost
			}>
		<#local list = list + [shipping]>
	</#if>
	<#--Handling-->
	<#if notZero(record.handlingcost) && ((record.handlingtax1rate?has_content && record.handlingtax1rate != 'A') || notZero(record.handlingcost))>
		<#if record.handlingtax2rate?has_content>
			<#local handlingrate = record.handlingtax1rate?number + record.handlingtax2rate?number>
		<#elseif record.handlingtax1rate?has_content>
			<#local handlingrate = record.handlingtax1rate>
		<#elseif record.taxrate?has_content && isTrue(record.handling_btaxable)>
			<#local handlingrate = record.taxrate>
		<#else>
			<#local handlingrate = 0>
		</#if>
		<#local handling = {
			"taxrate": handlingrate?string,
			"amount": record.handlingcost,
			"taxamount": (formattedStringToNumber(handlingrate) / 100) * record.handlingcost
			}>
			<#local list = list + [handling]>
	</#if>
</#if>
	<#list list as item>
		<#local itemtaxrate = getItemTaxRate(item, rec)>
		<#if itemtaxrate?has_content && !processed_tax_rates?seq_contains(itemtaxrate?string?replace('[^\\.,٬0-9]', '', 'r'))>
			<#local items = []>
			<#list list as item2>
				<#local item2taxrate = getItemTaxRate(item2, rec)>
				<#if item2taxrate?string?replace('[^\\.,٬0-9]','','r') == itemtaxrate?string?replace('[^\\.,٬0-9]','','r')><#local items = items + [item2]></#if>
			</#list>
			<#local result = result + [calculateVATsums(items, itemtaxrate)]>
			<#local processed_tax_rates = processed_tax_rates + [itemtaxrate?string?replace('[^\\.,٬0-9]', '', 'r')]>
		</#if>
	</#list>
	<#return result>
</#function>

<#-- Checks if at least one discount item -->
<#function isLeastOneItemDiscount items>
	<#list items as item>
		<#if item.itemtype == "Discount"><#return true></#if>
	</#list>
	<#return false>
</#function>