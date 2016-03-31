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
          for $token in (tokenize($formula, "(=|\\+|-)"), tokenize($condition, "( |0|=|\\+|-|<|>)"))
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
    let $formula-with-fact-trails as string := replace($formula, "rules:decimal-value\\(\\$([A-Za-z0-9]+)\\)", "rules:fact-trail(\\$$1, \"$1\")")
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
            $"||$source-fact||",\n
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
      "SourceFact" : [ "ComprehensiveIncomeLoss" ],
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
    end-rules: [ $converted-conditional-rules ]
}