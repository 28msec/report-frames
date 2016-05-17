import module namespace http-client = "http://zorba.io/modules/http-client";

declare variable $report external := "BalanceSheetClassified";

declare variable $links as array := [
  "https://www.dropbox.com/s/oq3isq3nds9ugw5/GeneralInformation.json?dl=1",
  "https://www.dropbox.com/s/kemb7h9wrwzrdro/BalanceSheetClassified.json?dl=1",
  "https://www.dropbox.com/s/k8e85yztolir6hd/BalanceSheetUnclassified.json?dl=1",
  "https://www.dropbox.com/s/tia5ovgao111lkc/IncomeStatementSingleStep_Special6.json?dl=1",
  "https://www.dropbox.com/s/4dkeplm77co76ds/IncomeStatementInterestBasedRevenues.json?dl=1",
  "https://www.dropbox.com/s/1tjkoofq8379vth/NetIncomeLossAvailableToCommonBreakdown.json?dl=1",
  "https://www.dropbox.com/s/kvjeuecgsm7pu33/NetIncomeLossBreakdown.json?dl=1",
  "https://www.dropbox.com/s/vs0hnboekgqvjg3/CashFlowStatement.json?dl=1",
  "https://www.dropbox.com/s/qzencr8y4h8va15/StatementOfComprehensiveIncome.json?dl=1",
  "https://www.dropbox.com/s/wai4tugrd65jvm2/ComprehensiveIncomeBreakdown.json?dl=1",
  "https://www.dropbox.com/s/ig87szklhi14edj/CashFlowStatement2.json?dl=1",
  "https://www.dropbox.com/s/ei04ioii7uflzei/ContinuingDiscontuedBreakdown.json?dl=1",
  "https://www.dropbox.com/s/hj0j5d3ehfs2xig/NetCashFlowBreakdown.json?dl=1",
  "https://www.dropbox.com/s/ojk30f8w6c1u0le/BalanceSheetCapitalization.json?dl=1",
  "https://www.dropbox.com/s/mmx5belyh1mfnyh/BalanceSheetClassified2.json?dl=1",
  "https://www.dropbox.com/s/o2azjgmh9ept054/BalanceSheetClassified4.json?dl=1",
  "https://www.dropbox.com/s/ax3wtln98fc4k0q/Basic.json?dl=1",
  "https://www.dropbox.com/s/upni7s0iaealc80/IncomeStatement3Step_CostsAndExpenses.json?dl=1",
  "https://www.dropbox.com/s/7m2ibjs1qg61bnp/IncomeStatement3Step_IEMI_Taxes.json?dl=1",
  "https://www.dropbox.com/s/bt6tuks3ok8breo/IncomeStatement3Step.json?dl=1",
  "https://www.dropbox.com/s/pk2l30t8ztd0w5s/IncomeStatement3StepGP2.json?dl=1",
  "https://www.dropbox.com/s/e2o39oebby8f6bo/IncomeStatement3StepGP.json?dl=1",
  "https://www.dropbox.com/s/dwkilhkk81pboll/IncomeStatementInsuranceBasedRevenues_IEMI_Taxes.json?dl=1",
  "https://www.dropbox.com/s/xj41zogaox5bn71/IncomeStatementInsuranceBasedRevenues_IEMI_Ignore.json?dl=1",
  "https://www.dropbox.com/s/qs42uuw5w4hbwjb/IncomeStatementInsuranceBasedRevenues.json?dl=1",
  "https://www.dropbox.com/s/a5j3sqcummr74ug/IncomeStatementMultiStep_IEMI_Taxes.json?dl=1",
  "https://www.dropbox.com/s/w2idclc7thfm00m/IncomeStatementMultiStep_IEMI_After.json?dl=1",
  "https://www.dropbox.com/s/0h7nx2nhnd8t7a5/IncomeStatementMultiStep_IEMI_Ignore.json?dl=1",
  "https://www.dropbox.com/s/tfqtqggdrg19b2t/IncomeStatementMultiStep.json?dl=1",
  "https://www.dropbox.com/s/o3kg3fg39g65hw2/IncomeStatementMultiStepWithoutOperatingIncome_IEMI_Taxes.json?dl=1",
  "https://www.dropbox.com/s/rl8a6e5zv5w8wi6/IncomeStatementMultiStepWithoutOperatingIncome.json?dl=1",
  "https://www.dropbox.com/s/a3wsmfwllritvfa/IncomeStatementREITMultiStep.json?dl=1",
  "https://www.dropbox.com/s/bglbo239tydqcui/StatementOfComprehensiveIncome2.json?dl=1",
  "https://www.dropbox.com/s/c9ejsux1udpvtn4/NetCashFlowBreakdown2.json?dl=1",
  "https://www.dropbox.com/s/exjnw1od49qa2z2/Park.json?dl=1",
  "https://www.dropbox.com/s/sf4shytndaqyqo5/KeyRatios.json?dl=1",
  "https://www.dropbox.com/s/z76k3xq24obzyc3/IncomeStatementREITSingleStep_IEMI_Taxes.json?dl=1",
  "https://www.dropbox.com/s/ks82q1j5gobe3lj/IncomeStatementREITSingleStep.json?dl=1",
  "https://www.dropbox.com/s/0vo8uxaoa8fkhal/IncomeStatementSecuritiesBasedIncome2.json?dl=1",
  "https://www.dropbox.com/s/0jcth9fvr506thk/IncomeStatementSecuritiesBasedIncome3_CITI.json?dl=1",
  "https://www.dropbox.com/s/prillydg89y3r6r/IncomeStatementSecuritiesBasedIncome.json?dl=1",
  "https://www.dropbox.com/s/z9ndxksy80wuvpr/IncomeStatementSingleStep_Special1_IEMI_Taxes.json?dl=1",
  "https://www.dropbox.com/s/xls6e15jbvzwb0p/IncomeStatementSingleStep_Special1.json?dl=1",
  "https://www.dropbox.com/s/janasi240qtk9na/IncomeStatementSingleStep_Special1A.json?dl=1",
  "https://www.dropbox.com/s/sgfehvzm2tqwkvm/IncomeStatementSingleStep_Special2_IEMI_Taxes.json?dl=1",
  "https://www.dropbox.com/s/6zjnmu9y63o8rc6/IncomeStatementSingleStep_Special2.json?dl=1",
  "https://www.dropbox.com/s/t6fk8zs74lg5xec/IncomeStatementSingleStep_Special2A.json?dl=1",
  "https://www.dropbox.com/s/t6fk8zs74lg5xec/IncomeStatementSingleStep_Special2A.json?dl=1",
  "https://www.dropbox.com/s/hwk3u1fa4los09c/IncomeStatementSingleStep_Special4.json?dl=1",
  "https://www.dropbox.com/s/j0zz3k21fv2bmcy/IncomeStatementSingleStep_Special6_IEMI_Taxes.json?dl=1",
  "https://www.dropbox.com/s/0hb0yref7d8wjcf/IncomeStatementSingleStep_Special8.json?dl=1",
  "https://www.dropbox.com/s/cq7cxqipjhgxr70/IncomeStatementSingleStep_Special9.json?dl=1",
  "https://www.dropbox.com/s/huvxtnfzzlyra81/IncomeStatementSingleStep_IEMI_Taxes.json?dl=1",
  "https://www.dropbox.com/s/nbhyyrmq2xwepuc/IncomeStatementSingleStep_IEMI_After.json?dl=1",
  "https://www.dropbox.com/s/miybaxrjrsrxes8/IncomeStatementSingleStep_IEMI_Ignore.json?dl=1",
  "https://www.dropbox.com/s/rx95p19ug7s1mjm/IncomeStatementSingleStep.json?dl=1",
  "https://www.dropbox.com/s/hhb9bd7hewmpfj6/IncomeStatementSingleStepWithoutOperatingIncome_NoExpenseTotal.json?dl=1",
  "https://www.dropbox.com/s/2yqnor40jzwoey0/IncomeStatementSingleStepWithoutOperatingIncome_IEMI_Taxes.json?dl=1",
  "https://www.dropbox.com/s/n1id7sv5aiyu4ar/IncomeStatementSingleStepWithoutOperatingIncome.json?dl=1",
  "https://www.dropbox.com/s/eyhlll6uc7qolf8/ValidationResults2.json?dl=1",
  "https://www.dropbox.com/s/7cncrtk7klwmatu/ValidationResults.json?dl=1"
];

let $json := parse-json(http-client:get-text($links[][contains($$, $report||".json")]).body.content)
let $rules := parse-json(http-client:get-text("http://report-frames.28.io/generate-new.jq?report="||$report).body.content)
let $component as object := $json[$$.Role ne "http://www.xbrl.org/2003/role/link"]
return copy $c := $component
modify (
    replace value of json $c.Archive with null,
    insert json {  "Owner" : "admin@28.io",
          "Description" : "Report frame "||$report||", 2016, v3, by Charles Hoffman (see http://www.xbrlsite.com/2016/fac/v3/Documentation/)." ,
          "ACL" : [ {
            "Type" : "Group",
            "Grantee" : "http://28.io/groups/AllUsers",
            "Permission" : "READ"
          } ],
          "LastModified" : "2015-04-23T09:34:54.006577Z",
          "DefinitionModels" : [ {
              "ModelKind" : "DefinitionModel",
              "Labels" : [ "Fundamental Accounting Concepts" ],
              "Parameters" : {

              },
              "Breakdowns" : {
                "x" : [ {
                  "BreakdownLabels" : [ "Reporting Entity Breakdown" ],
                  "BreakdownTrees" : [ {
                    "Kind" : "Rule",
                    "Abstract" : true,
                    "Labels" : [ "Reporting Entity [Axis]" ],
                    "Children" : [ {
                      "Kind" : "Aspect",
                      "Aspect" : "xbrl:Entity"
                    } ]
                  } ]
                }, {
                  "BreakdownLabels" : [ "Fiscal Year Breakdown" ],
                  "BreakdownTrees" : [ {
                    "Kind" : "Rule",
                    "Abstract" : true,
                    "Labels" : [ "Fiscal Year [Axis]" ],
                    "Children" : [ {
                      "Kind" : "Aspect",
                      "Aspect" : "xbrl28:FiscalYear"
                    } ]
                  } ]
                }, {
                  "BreakdownLabels" : [ "Fiscal Period Breakdown" ],
                  "BreakdownTrees" : [ {
                    "Kind" : "Rule",
                    "Abstract" : true,
                    "Labels" : [ "Fiscal Period [Axis]" ],
                    "Children" : [ {
                      "Kind" : "Aspect",
                      "Aspect" : "xbrl28:FiscalPeriod"
                    } ]
                  } ]
                } ],
                "y" : [ {
                  "BreakdownLabels" : [ "Breakdown on concepts" ],
                  "BreakdownTrees" : [ {
                    "Kind" : "ConceptRelationship",
                    "LinkName" : "link:presentationLink",
                    "LinkRole" : $c.Role,
                    "ArcName" : "link:presentationArc",
                    "ArcRole" : "http://www.xbrl.org/2003/arcrole/parent-child",
                    "RelationshipSource" : $c.Concepts[][$$.Kind eq "LineItems"].Name,
                    "FormulaAxis" : "descendant",
                    "Generations" : 0
                  } ]
                } ]
              },
              "TableFilters" : {

              }
            }
          ]
    } into $c,
    replace value of json $c.Rules with [ $c.Rules[], $rules.end-rules[] ],
    replace value of json $c._id with tokenize($c.Role, "/")[last()]
)
return $c
