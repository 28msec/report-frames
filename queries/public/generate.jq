import module namespace http-client = "http://zorba.io/modules/http-client";
import module namespace random = "http://zorba.io/modules/random";

let $text := http-client:get-text("https://www.dropbox.com/s/hyft1l20skzfg2u/ImputeRules.txt?dl=1").body.content
let $lines := tokenize($text, "\n")
for tumbling window $individual-report in $lines
start $s when starts-with($s, "'XXX")
end next $t when starts-with($t, "'XXX")
return
let $role := replace($individual-report[1], ".*\\((http://[^\\)]*)\\)\r", "$1")
let $label := replace($individual-report[1], "'X+ NETWORK: (.*) \\(.*\r", "$1")
let $raw-rules :=
  for tumbling window $individual-rule in $individual-report
  start $s when starts-with($s, "    '")
  end next $t when starts-with($t, "    '")
  return
        let $label := replace($individual-rule[1], " *'(.*):.*\r", "$1")
        let $is-validation := starts-with($label, "VERIFICATION RULES")
        return if($is-validation)
        then 
            for $rule in $individual-rule
            where contains($rule, "=")
            let $formula := replace($rule, " *(.+)\r", "$1")
            let $target-concept := replace($formula, " *([A-Za-z0-9]+) = .*", "$1")
            let $other-concepts :=
                for $token in tokenize($formula, "(=|\\+|-|\\)|\\(| )")[position() gt 1]
                where $token ne ""
                return replace($token, " *([A-Za-z0-9]+) *", "$1")
            return {
                Validation: true,
                Formula: $formula,
                TargetConcept: $target-concept,
                DependsOn: [ $other-concepts ]
            }
        else 
        let $is-conditional := starts-with($individual-rule[2], "    If")
        let $condition := if($is-conditional) then replace($individual-rule[2], " *If (.+) Then\r", "$1") else ""
        let $formula := if($is-conditional) then replace($individual-rule[3], " *(.+)\r", "$1") else replace($individual-rule[2], "    (.*)\r", "$1")
        let $target-concept := replace($formula, " *([A-Za-z]+) = .*", "$1")
        let $other-concepts :=
          for $token in tokenize($formula, "(=|\\+|-)")
          return replace($token, " *([A-Za-z]+) *", "$1")
        where count($individual-rule) gt 1
        return {
            Label: $label,
            Conditional: $is-conditional,
            Validation: $is-validation,
            Condition: $condition,
            Formula: $formula,
            TargetConcept: $target-concept,
            DependsOn: [ $other-concepts ]
        }
let $converted-conditional-rules :=
  for $target-concept in distinct-values($raw-rules[$$.Conditional].TargetConcept)
  let $rules := $raw-rules[$$.TargetConcept = $target-concept]
  let $depends-on := distinct-values($rules.DependsOn[])
  return {
    "Id" : random:uuid(),
    "OriginalLanguage" : "SpreadsheetFormula",
    "Type" : "xbrl28:formula",
    "ComputableConcepts" : [ $target-concept ],
    "DependsOn" : [ $depends-on ],
    "Formula" : "\n
    for $facts in facts:facts-for-internal((\n" ||
    string-join($depends-on ! ("\"fac:" || $$ || "\""), ", ")
    ||"), $hypercube, $aligned-filter, $concept-maps, $rules, $cache, $options)\n
    let $duration-period as object? := facts:duration-for-fact($facts, {Typed: false })\n
    let $instant-period as string?  := facts:instant-for-fact($facts, {Typed: false })\n
    let $aligned-period as string  := ( $duration-period.End, $instant-period, \"forever\")[1]\n
    group by $canonical-filter-string :=\n  facts:canonical-grouping-key($facts, ($facts:CONCEPT, $facts:UNIT, $facts:PERIOD))\n
    , $aligned-period\n
    for $duration-string as string? allowing empty in distinct-values($facts[$$.Concept.PeriodType eq \"duration\"].$facts:ASPECTS.$facts:PERIOD)\n
    let $facts := $facts[$$.$facts:ASPECTS.$facts:PERIOD = ($duration-string, $aligned-period)]\n" ||
    string-join(for $concept in $depends-on
     return
        "let $warnings as string* := ()\n
        let $"||$concept||" as object* := $facts[$$.$facts:ASPECTS.$facts:CONCEPT eq \"fac:"||$concept||"\"]\n
        let $warnings := ($warnings, if(count($"||$concept||") gt 1)\n
        then if(count(distinct-values($"||$concept||".Value)) gt 1)\n
        then \"Cell collision with conflicting values for concept "||$concept||".\"\n
        else \"Cell collision with consistent values for concept "||$concept||".\"\n
        else ())\n
        let $"||$concept||" as object? := $"||$concept||"[1]\n")

    || "let $_unit := ($facts.$facts:ASPECTS.$facts:UNIT)[1]\n
    return\n
    switch (true)\n
    case exists($ComprehensiveIncomeLossAttributableToParent) return $ComprehensiveIncomeLossAttributableToParent\n
    case (exists($ComprehensiveIncomeLoss) and (not((not(exists($ComprehensiveIncomeLoss)))) and not(exists($ComprehensiveIncomeLossAttributableToNoncontrollingInterest))))\n
    return\n
    let $computed-value := rules:decimal-value($ComprehensiveIncomeLoss)\n
    let $audit-trail-message as string* := \n
    rules:fact-trail({\"Aspects\": { \"xbrl:Unit\" : $_unit, \"xbrl:Concept\" : \"fac:ComprehensiveIncomeLossAttributableToParent\" }, Value: $computed-value }) || \" = \" || \n
    rules:fact-trail($ComprehensiveIncomeLoss, \"ComprehensiveIncomeLoss\")\n
    let $audit-trail-message as string* := ($audit-trail-message, $warnings)\n
    let $source-facts as object* := ($ComprehensiveIncomeLossAttributableToParent, $ComprehensiveIncomeLoss, $ComprehensiveIncomeLossAttributableToNoncontrollingInterest, $IncomeLossBeforeEquityMethodInvestments, $NetIncomeLoss)\n
    let $rule as object :=\n
    copy $newRule := $rule\n
    modify (\n
    if(exists($newRule(\"Label\"))) then ()\n
    else insert json { \"Label\": \"Comprehensive Income (Loss) Attributable to Parent\" } into $newRule\n
    )\n
    return $newRule\n
    let $fact as object :=\n
    rules:create-computed-fact(\n
    $ComprehensiveIncomeLoss,\n
    \"fac:ComprehensiveIncomeLossAttributableToParent\",\n
    $computed-value,\n
    $rule,\n
    $audit-trail-message,\n
    $source-facts,\n
    $options)\n
    return\n
    copy $newFact := $fact\n
    modify (\n
    if(exists($newFact(\"Aspects\")(\"xbrl:Unit\"))) then replace value of json $newFact(\"Aspects\")(\"xbrl:Unit\") with $_unit\n
    else insert json { \"xbrl:Unit\": $_unit } into $newFact(\"Aspects\")\n
    ,\n
    if(exists($newFact(\"Concept\")(\"DataType\"))) then replace value of json $newFact(\"Concept\")(\"DataType\") with \"xbrli:monetaryItemType\"\n                                                         else insert json { \"DataType\": \"xbrli:monetaryItemType\" } into $newFact(\"Concept\")\n            ,\n              if(exists($newFact(\"Concept\")(\"PeriodType\"))) then replace value of json $newFact(\"Concept\")(\"PeriodType\") with \"duration\"\n                                                         else insert json { \"PeriodType\": \"duration\" } into $newFact(\"Concept\")\n          )\n        return $newFact\n  case (exists($ComprehensiveIncomeLoss) and (not(exists($ComprehensiveIncomeLoss)) and not(exists($ComprehensiveIncomeLossAttributableToNoncontrollingInterest)) and not(exists($IncomeLossBeforeEquityMethodInvestments)) and not((not(exists($NetIncomeLoss))))))\n  return\n    let $computed-value := rules:decimal-value($NetIncomeLoss)\n    let $audit-trail-message as string* := \n      rules:fact-trail({\"Aspects\": { \"xbrl:Unit\" : $_unit, \"xbrl:Concept\" : \"fac:ComprehensiveIncomeLossAttributableToParent\" }, Value: $computed-value }) || \" = \" || \n         rules:fact-trail($NetIncomeLoss, \"NetIncomeLoss\")\n    let $audit-trail-message as string* := ($audit-trail-message, $warnings)\n    let $source-facts as object* := ($ComprehensiveIncomeLossAttributableToParent, $ComprehensiveIncomeLoss, $ComprehensiveIncomeLossAttributableToNoncontrollingInterest, $IncomeLossBeforeEquityMethodInvestments, $NetIncomeLoss)\n    let $rule as object :=\n        copy $newRule := $rule\n        modify (\n            if(exists($newRule(\"Label\"))) then ()\n                                          else insert json { \"Label\": \"Comprehensive Income (Loss) Attributable to Parent\" } into $newRule\n          )\n        return $newRule\n    let $fact as object :=\n        rules:create-computed-fact(\n          $ComprehensiveIncomeLoss,\n          \"fac:ComprehensiveIncomeLossAttributableToParent\",\n          $computed-value,\n          $rule,\n          $audit-trail-message,\n          $source-facts,\n            $options)\n    return\n        copy $newFact := $fact\n        modify (\n            if(exists($newFact(\"Aspects\")(\"xbrl:Unit\"))) then replace value of json $newFact(\"Aspects\")(\"xbrl:Unit\") with $_unit\n                                                         else insert json { \"xbrl:Unit\": $_unit } into $newFact(\"Aspects\")\n            ,\n              if(exists($newFact(\"Concept\")(\"DataType\"))) then replace value of json $newFact(\"Concept\")(\"DataType\") with \"xbrli:monetaryItemType\"\n                                                         else insert json { \"DataType\": \"xbrli:monetaryItemType\" } into $newFact(\"Concept\")\n            ,\n              if(exists($newFact(\"Concept\")(\"PeriodType\"))) then replace value of json $newFact(\"Concept\")(\"PeriodType\") with \"duration\"\n                                                         else insert json { \"PeriodType\": \"duration\" } into $newFact(\"Concept\")\n          )\n        return $newFact\n  default return ()",
    "Formulae" : [ for $r in $rules return {
      "PrereqSrc" : $r.Condition,
      "SourceFact" : [ "ComprehensiveIncomeLoss" ],
      "BodySrc" : $r.Formula
    } ],
    "AllowCrossPeriod" : true,
    "AllowCrossBalance" : true,
    "HideRulesForConcepts" : [  ]
  }
return {
    role: $role,
    label: $label,
    rules: [ $raw-rules ],
    end-rules: [ $converted-conditional-rules ]
}