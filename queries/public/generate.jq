import module namespace http-client = "http://zorba.io/modules/http-client";
import module namespace random = "http://zorba.io/modules/random";

declare variable $report external := "COMID-BSC-CF1-ISM-IEMIB-OILY-SPEC6";

declare function local:replace($condition as string) as string
{
    let $condition as string := replace($condition, "([a-zA-Z0-9]+) = 0", "empty(\\$$1)")
    let $condition as string := replace($condition, "([a-zA-Z0-9]+) <> 0", "exists(\\$$1)")
    let $condition as string := replace($condition, "([a-zA-Z0-9]+)", "rules:decimal-value(\\$$1)")
    let $condition as string := replace($condition, "rules:decimal-value\\(\\$empty\\)", "empty")
    let $condition as string := replace($condition, "rules:decimal-value\\(\\$exists\\)", "exists")
    let $condition as string := replace($condition, "rules:decimal-value\\(\\$and\\)", "and")
    let $condition as string := replace($condition, "rules:decimal-value\\(\\$or\\)", "or")
    let $condition as string := replace($condition, "\\$rules:decimal-value\\(([^\\)]*)\\)", "$1")
    let $condition as string := replace($condition, "=", "eq")
    let $condition as string := replace($condition, "<>", "ne")
    return $condition
};

let $text := http-client:get-text("http://www.xbrlsite.com/2015/fro/us-gaap/html/ReportFrames/"||$report||"/ImputeRules.txt").body.content
let $lines := tokenize($text, "\n")
for tumbling window $individual-report in $lines
start $s when starts-with($s, "'XXX")
end next $t when starts-with($t, "'XXX")
return
let $role := replace($individual-report[1], ".*\\((http://[^\\)]*)\\)", "$1")
let $label := replace($individual-report[1], "'X+ NETWORK: (.*) \\(.*", "$1")
let $raw-rules :=
  for tumbling window $individual-rule in $individual-report
  start $s when starts-with($s, "    '")
  end next $t when starts-with($t, "    '")
  return
        let $label := replace($individual-rule[1], " *'(.*)", "$1")
        let $is-validation := starts-with($label, "VERIFICATION RULES")
        return if($is-validation)
        then 
            for $rule in $individual-rule
            where contains($rule, "=")
            let $formula := replace($rule, " *(.+)", "$1")
            let $target-concept := replace($formula, " *([A-Za-z0-9]+) = .*", "$1")
            let $formula := replace($formula, " *[A-Za-z0-9]+ = (.*)", "$1")
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
        let $condition := if($is-conditional) then replace($individual-rule[2], " *If (.+) Then", "$1") else ""
        let $formula := if($is-conditional) then replace($individual-rule[3], " *(.+)", "$1") else replace($individual-rule[2], "    (.*)", "$1")
        let $target-concept := replace($formula, " *([A-Za-z]+) = .*", "$1")
        let $formula := replace($formula, " *[A-Za-z0-9]+ = (.*)", "$1")
        let $other-concepts := distinct-values(
          for $token in (tokenize($formula, "(\\(|\\)|=|\\+|-)"), tokenize($condition, "(\\(|\\)| |0|=|\\+|-|<|>)"))
          where not $token = ("", " ", "and", "or")
          return replace($token, " *([A-Za-z]+) *", "$1"))
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
  for tumbling window $rules in $raw-rules[$$.Conditional]
  start when true
  end $s next $t when $t.TargetConcept ne $s.TargetConcept
  let $target-concept as string := distinct-values($rules.TargetConcept)
  let $depends-on := distinct-values($rules.DependsOn[])
  let $source-fact as string := $depends-on[$$ ne $target-concept][1]
  return {
    "Id" : random:uuid(),
    "Label" : "Computation of " || $target-concept,
    "OriginalLanguage" : "SpreadsheetFormula",
    "Type" : "xbrl28:formula",
    "ComputableConcepts" : [ "fac:"||$target-concept ],
    "DependsOn" : [ $depends-on ! ("fac:" || $$) ],
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
    let $facts := $facts[$$.$facts:ASPECTS.$facts:PERIOD = ($duration-string, $aligned-period)]\n
    let $warnings as string* := ()\n" ||
    string-join(for $concept in ($target-concept, $depends-on)
     return
        "let $"||$concept||" as object* := $facts[$$.$facts:ASPECTS.$facts:CONCEPT eq \"fac:"||$concept||"\"]\n
        let $warnings := ($warnings, if(count($"||$concept||") gt 1)\n
        then if(count(distinct-values($"||$concept||".Value)) gt 1)\n
        then \"Cell collision with conflicting values for concept "||$concept||".\"\n
        else \"Cell collision with consistent values for concept "||$concept||".\"\n
        else ())\n
        let $"||$concept||" as object? := $"||$concept||"[1]\n")

    || "let $_unit := ($facts.$facts:ASPECTS.$facts:UNIT)[1]\n
    return\n
    switch (true)\n" ||
    (
        if(every $rule in $rules satisfies contains($rule.Condition, $target-concept || " = 0"))
        then
            "case exists($"||$target-concept||") return $"||$target-concept||"\n"
        else ()
    )||string-join(
    for $rule in $rules
    let $condition as string := local:replace($rule.Condition)
    let $formula as string := local:replace($rule.Formula)
    let $formula-with-fact-trails as string := "\"" || replace($formula, "rules:decimal-value\\(\\$([A-Za-z0-9]+)\\)", "\"||rules:fact-trail(\\$$1, \"$1\")||\"") || "\""
    return
    "case "||$condition||"\n
    return\n
        let $computed-value := "||$formula||"\n
        let $audit-trail-message as string* := \n
            rules:fact-trail({\"Aspects\": { \"xbrl:Unit\" : $_unit, \"xbrl:Concept\" : \""||$target-concept||"\" }, Value: $computed-value }) || \" = \" || \n
            "||$formula-with-fact-trails||"\n
        let $audit-trail-message as string* := ($audit-trail-message, $warnings)\n
        let $source-facts as object* := ("||string-join($depends-on ! ("$" || $$), ", ")||")\n
        let $rule as object :=\n
            copy $newRule := $rule\n
            modify (\n
                if(exists($newRule(\"Label\"))) then ()\n
                else insert json { \"Label\": \"Comprehensive Income (Loss) Attributable to Parent\" } into $newRule\n
            )\n
            return $newRule\n
        let $fact as object :=\n
        rules:create-computed-fact(\n
            ($"||$source-fact||", $source-facts)[1],\n
            \"fac:"||$target-concept||"\",\n
            $computed-value,\n
            $rule,\n
            $audit-trail-message,\n
            $source-facts,\n
            $options)\n
        return\n
        copy $newFact := $fact\n
        modify (\n
        if(exists($newFact(\"Aspects\")(\"xbrl:Unit\"))) then replace value of json $newFact(\"Aspects\")(\"xbrl:Unit\") with             $_unit\n
        else insert json { \"xbrl:Unit\": $_unit } into $newFact(\"Aspects\")\n
        ,\n
        if(exists($newFact(\"Concept\")(\"DataType\"))) then replace value of json $newFact(\"Concept\")(\"DataType\") with \"xbrli:monetaryItemType\"\n
        else insert json { \"DataType\": \"xbrli:monetaryItemType\" } into $newFact(\"Concept\")\n
        ,\n
        if(exists($newFact(\"Concept\")(\"PeriodType\"))) then replace value of json $newFact(\"Concept\")(\"PeriodType\") with \"duration\"\n
        else insert json { \"PeriodType\": \"duration\" } into $newFact(\"Concept\")\n
        )\n
        return $newFact\n"
        )||"default return ()",
    "Formulae" : [ for $r in $rules return {
      "PrereqSrc" : local:replace($r.Condition),
      "SourceFact" : [ $source-fact ],
      "BodySrc" : local:replace($r.Formula)
    } ],
    "AllowCrossPeriod" : true,
    "AllowCrossBalance" : true,
    "HideRulesForConcepts" : [  ]
  }
return {
    role: $role,
    label: $label,
    rules: [ $raw-rules ],
    end-rules: [
        $converted-conditional-rules, {
    "Id" : "default_zero",
    "Type" : "xbrl28:formula",
    "Label" : "Zeros instead of null",
    "Formula" : "import module namespace r = \"http://zorba.io/modules/random\";\r\n\r\n                     let $concept-dimension as object := dimensions:dimension-for-hypercube($hypercube, $facts:CONCEPT)\r\n                     let $concepts-in-report as string* := dimensions:member-names($concept-dimension)[$$ = $options.Concepts[].Name]\r\n                     let $non-numeric-concepts := $options.Concepts[][not($$.DataType = (\"xbrli:monetaryItemType\",\"xbrli:pureItemType\"))].Name\r\n                     let $abstract-concepts := $options.Concepts[][$$.IsAbstract].Name\r\n                     let $numeric-concepts := $concepts[not($$ = $non-numeric-concepts) and not($$ = $abstract-concepts) and $$ = $concepts-in-report]\r\n                     let $numeric-instant-concepts := $options.Concepts[][$$.PeriodType eq \"instant\"].Name\r\n                     let $numeric-duration-concepts := $numeric-concepts[not($$ = $numeric-instant-concepts)]\r\n                     let $numeric-instant-concepts := $numeric-concepts[$$ = $numeric-instant-concepts]\r\n                     let $concepts-not-in-report := trace($concepts[not $$ = $concepts-in-report], \"not\")\r\n                     return\r\n                     for $facts in facts:facts-for-internal($concepts, $hypercube, $aligned-filter, $concept-maps, $rules, $cache, $options)\r\n                     group by facts:canonical-grouping-key($facts, ($facts:CONCEPT, $facts:UNIT))\r\n                     let $template-fact as object := ($facts[$$.$facts:ASPECTS.$facts:CONCEPT = $numeric-concepts], $facts)[1]\r\n                     let $is-instant := not contains($template-fact.$facts:ASPECTS.$facts:PERIOD, \"/\")\r\n                     return (\r\n                             $facts[$$.$facts:ASPECTS.$facts:CONCEPT = $concepts-not-in-report],\r\n                             $facts[$$.$facts:ASPECTS.$facts:CONCEPT = $non-numeric-concepts],\r\n\r\n                             (: default 0 :)\r\n                             let $concepts-with-relevant-period-type := if($is-instant) then $numeric-instant-concepts else $numeric-duration-concepts\r\n                             for $concept in $concepts-with-relevant-period-type\r\n                             let $fact as object? := $facts[$$.$facts:ASPECTS.$facts:CONCEPT eq $concept]\r\n                     \t\tlet $concept-meta as object? := $options.Concepts[][$$.Name eq $concept]\r\n                             return switch(true)\r\n                               (: fill empty cell with zero :)\r\n                               case empty($fact)\r\n                               return\r\n                                 let $audit-trail := {\r\n                                   \"Type\" : \"xbrl28:default-fact-value\",\r\n                                   \"Label\" : \"Default fact value\",\r\n                                   \"Message\" : $concept || \" = 0\",\r\n                                   \"Data\" : {\r\n                                     \"OutputConcept\" : $concept\r\n                                   }\r\n                                 }\r\n                                 return\r\n                                 copy $f := $template-fact\r\n                                 modify (\r\n                                     replace value of json $f._id with r:uuid(),\r\n                                     replace value of json $f.$facts:ASPECTS.$facts:CONCEPT with $concept,\r\n                                     replace value of json $f.Value with 0,\r\n                                     replace value of json $f.Type with \"NumericValue\",\r\n                                     if(exists($f.Decimals))\r\n                                     then replace value of json $f.Decimals with 0\r\n                                     else insert json { Decimals: 2 } into $f,\r\n                                     if(exists($f.AuditTrails))\r\n                                     then replace value of json $f.AuditTrails with [ $audit-trail ]\r\n                                     else insert json { AuditTrails: [ $audit-trail ] } into $f,\r\n                     \t\t\t\tif($concept-meta)\r\n                     \t\t\t\tthen (\r\n                     \t\t\t\t\tif($f.Concept.PeriodType)\r\n                     \t\t\t\t\tthen replace value of json $f.Concept.PeriodType with $concept-meta.PeriodType\r\n                     \t\t\t\t\telse insert json { \"PeriodType\": $concept-meta.PeriodType } into $f.Concept,\r\n                     \t\t\t\t\tif($f.Concept.DataType)\r\n                     \t\t\t\t\tthen replace value of json $f.Concept.DataType with $concept-meta.DataType\r\n                     \t\t\t\t\telse insert json { \"DataType\": $concept-meta.DataType } into $f.Concept\r\n                     \t\t\t\t) else ()\r\n                                 )\r\n                                 return $f\r\n\r\n                             (: replacing null with zero :)\r\n                             case $fact.Type eq \"NumericValue\" and $fact.Value eq null\r\n                             return\r\n                                     let $concept := $fact.$facts:ASPECTS.$facts:CONCEPT\r\n                                     let $audit-trail := {\r\n                                         Type: \"xbrl28:null-to-zero\",\r\n                                         Label: \"Adapting null value\",\r\n                                         Message: \"Replacing null value with 0.\",\r\n                                         Data:\r\n                                             { OutputConcept: $concept }\r\n                                     }\r\n                                     return\r\n                                         copy $f := $fact\r\n                                         modify (\r\n                                             replace value of json $f.Value with 0,\r\n                     \t\t\t\t\t\tif(exists($f.Decimals))\r\n                     \t\t\t\t\t\tthen replace value of json $f.Decimals with 0\r\n                     \t\t\t\t\t\telse insert json { Decimals: 2 } into $f,\r\n                                             if(exists($f.AuditTrails))\r\n                                             then append json $audit-trail into $f.AuditTrails\r\n                                             else insert json { AuditTrails: [ $audit-trail ] } into $f\r\n                                         )\r\n                                         return $f\r\n\r\n                             default return $fact\r\n                         )"
    }
  ]
}