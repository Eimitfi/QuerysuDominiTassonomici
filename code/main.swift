//
//  main.swift
//  LogicPreferencePropagation
//
//  Created by Davide Martinenghi on 01/10/2020.
//  Copyright © 2020 Davide Martinenghi. All rights reserved.
//

import Foundation

Globals.quiet = true


let myConf:Configurator = try MyJSONConfigurator(path: "/Users/micheleiftimie/Desktop/tesi/SimplePreferencePropagation/SimplePreferencePropagation/configurazione.json")

var cSchema:ConfigSchema = try! myConf.getConfigSchema()

let stringPref = """
UserPrefs
F1(x,y): x[price] ≤ cheap & y[price] ≤ expensive
F2(x,y): x[artist] ≤ Machine Gun Kelly & y[artist] ≤ pop
F3(x,y): x[venue] ≤ InDoor & x[day] ≤ winter & y[venue] ≤ OutDoor & y[day] ≤ winter
"""


let fullSchema = try cSchema.getFullSchema(formula: stringPref)
for emel in fullSchema.taxonomies{
    print(emel.levelDescription())
    print(emel)
}
let inputStandardPrefs = try DNF(from: stringPref, schema: fullSchema)
let system = LogicalSystem(taxonomies: fullSchema.taxonomies, preferences: inputStandardPrefs)
let resultingPrefs = system.applySequence(sequence: "STST")
// stampa della descrizione del risultato in formato standard
print(resultingPrefs.logicalDescription)

print("******************")
var attrToType:[Attribute:ConfigTaxonomy.Type] = [:]
var attrToRules:[Attribute:RuleBasedConfigTax] = [:]
var attrToTemplates:[Attribute:[ResultTemplate]] = [:]
attrToTemplates["artist"] = [SameTableTemplate.init(moreSpecificAttribute: "moreSpecific", moreGenericAttribute: "moreGeneric", tableName: "artistTax")]
attrToTemplates["venue"] = [JoinTemplate.init(moreSpecificAttribute: "venue", moreGenericAttribute: "moreGeneric", moreSpecificTable: "concerts", moreGenericTable: "venuesLink", moreSpecificJoinAttribute: "id", moreGenericJoinAttribute: "id")]
for (attr,type) in cSchema.attribute2ConfigTaxonomy{
    if type is RuleBasedConfigTax{
        attrToRules[attr] = type as? RuleBasedConfigTax
        attrToType[attr] = RuleBasedConfigTax.self
    }else if type is QueryBasedConfigTax{
        attrToType[attr] = QueryBasedConfigTax.self
    }else if type is EmptyConfigTax{
        attrToType[attr] = EmptyConfigTax.self
    }
}

let configAlg = try ConfigResultAlgorithm.init(attributeOrdering: fullSchema.attributes, connInfo: cSchema.retriever.getConnInfo(), tRelationName: "concerts", attrToTaxType: attrToType, attributesToTemplates: attrToTemplates, attributesToRules: attrToRules)

let algorithm = try ModifiedLBAAlgorithm.init(preferences: resultingPrefs, schema: fullSchema, configAlg: configAlg)
print("results")
let res = try algorithm.getPreferredTuples()

for (i,elem) in res.enumerated(){
    print("level \(i): " + elem.description)
}

/*
let taxn = FormulaNodesGerarchy.init(formula: FormulaCleaner.cleanFormula(preferences: resultingPrefs))
print(taxn.description)
*/
/*
// esempio di tassonomia standard
let taxCarsString =
"""
alfa-romeo:Italy.
bmw:Germany.
cadillac:United_States.
ferrari:Italy.
ford:United_States.
mercedes-benz:Germany.
mini:Germany.
nissan:Japan.
porsche:Germany.
toyota:Japan.
volkswagen:Germany.
volvo:Sweden.
"""

// esempio di tassonomia flat
let taxPricesString =
"""
cheap
medium
expensive
"""


// esempio di preferenze in ingresso espresse in formato semplice
let inputPrefsString =
"""
UserPrefs
F1: alfa-romeo ⪰ Germany
F2: Italy & expensive ⪰ Italy & cheap
F3: Germany ⪰ Italy
"""

// costruzione della tassonomia delle macchine (standard)
guard let taxonomyCars = try? Taxonomy(from: taxCarsString, precomputed: true) else { exit(0) }
guard let taxonomyPrices = try? Taxonomy(flat: taxPricesString,precomputed: true) else {exit(0)}

// costruzione delle preferenze da trattare
//let inputPrefs = try DNF(from: inputPrefsString, taxonomies: [taxonomyCars, taxonomyPrices])
// sistema di elaborazione delle preferenze
//let system = LogicalSystem(taxonomies: [taxonomyCars, taxonomyPrices], preferences: inputPrefs)

// calcolo dele preferenze risultanti
//let resultingPrefs = system.applySequence(sequence: "STST")

// stampa della descrizione del risultato (con commenti che si possono ignorare)
//print(resultingPrefs)


// stesse preferenze espresse in formato standard
/*
let inputPrefsStandardString =
"""
UserPrefs
F1(x,y): x[A1] ≤ alfa-romeo & y[A1] ≤ Germany
F2(x,y): x[A1] ≤ Italy & x[A2] ≤ expensive & y[A1] ≤ Germany & y[A2] ≤ cheap
F3(x,y): x[A1] ≤ Germany & y[A1] ≤ Italy
"""
*/
let inputPrefsStandardString = """
UserPrefs
F1(x,y): x[A1] ≤ mini & y[A1] ≤ Japan
F2(x,y): x[A1] ≤ Sweden & y[A1] ≤ Italy
F3(x,y): x[A2] ≤ cheap & y[A2] ≤ expensive
"""
// stessa cosa con le preferenze standard
let inputStandardPrefs = try DNF(from: inputPrefsStandardString, taxonomies: [taxonomyCars, taxonomyPrices])

let system2 = LogicalSystem(taxonomies: [taxonomyCars, taxonomyPrices], preferences: inputStandardPrefs)
let resultingPrefs2 = system2.applySequence(sequence: "STST")
// stampa della descrizione del risultato in formato standard
print(resultingPrefs2.logicalDescription)
print("******")
 
*/
