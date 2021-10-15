//
//  DynamicFormula.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Iftimie on 06/05/2021.
//

import Foundation

public enum FormulaError:Error{
    case DynamicNodeNotFound(node:String)
    case AttributeNotInSchema(attribute:String)
}

public enum SchemaError:Error{
    case WrongGivenFormula(formula:String, info:String)
    case NoGivenDynamicQuery(attribute:String)
}

extension ConfigSchema{
    public func getFixedSchema(pathFrom:String = "", pathTo:String = "") throws -> Schema {
        var res:Schema
        if pathFrom == "" {
            res = try self.attachCommonChildren(schema: try self.getStaticSchema())
        }else{
            res = try Schema.fromStringDeserialization(schema: String(contentsOfFile: pathFrom, encoding: .utf8))
        }
        
        if pathTo != "" {
            try res.toStringSerialization().write(toFile: pathTo, atomically: false, encoding: .utf8)
        }
        
        return res
    }
}

extension ConfigSchema{
    public func getStaticSchema() throws -> Schema{
        var attrRes:[Attribute] = []
        var taxRes:[Taxonomy] = []
        for (a,t) in self.attribute2ConfigTaxonomy{
            attrRes.append(a)
            taxRes.append(try self.retriever.getStaticTaxonomy(config: t))
        }
        return Schema(attributes: attrRes, taxonomies: taxRes)
    }
}

extension ConfigSchema{
    public func attachCommonChildren(schema:Schema) throws -> Schema{
        var res = schema
        var attrToNodes:[Attribute:LightTaxonomy] = [:]
        var simpleTax:LightTaxonomy
        var config:ConfigTaxonomy
        
        //prepara le tassonomie semplici (si possono far fare le due cose direttamente nel retriever)
        for (attr,tax) in schema.attribute2Taxonomy{
            config = self.attribute2ConfigTaxonomy[attr]!
            
            simpleTax = LightTaxonomy.init(nodes:  Set<String>(tax.valuesDictionary.keys))
            try self.retriever.getSimpleIntersections(taxonomy: &simpleTax, config: config)
            attrToNodes[attr] = simpleTax
        }
        
        //algoritmo vero e proprio che raccoglie le intersezioni
        //si potrebbero far fare entrambe le cose alla tassonomia
        for (attr,tax) in attrToNodes{
            var index = 2
            var tmpTax = tax
            while (tax.nodes.count - 1 >= index && !tax.nodes.isEmpty) {
                tmpTax.removeUnusedNodes(index: index)
                tmpTax.addILevelIntersections(level:index + 1)
                index = index + 1
                
            }
            tmpTax.removeUselessIntersections()
            var taxon = schema.attribute2Taxonomy[attr]!
            taxon.addValues(valuePairs: tmpTax.getValues())
            let i = schema.attributes.firstIndex(of: attr)
            res.attribute2Taxonomy[attr] = taxon
            res.taxonomies[i!] = taxon
            
        }
        
        return res
    }
}

extension ConfigSchema{
    
    public func attachDynamicNodesToFixedTaxonomy(schema:Schema, formula:String) throws -> Schema{
        return try self.attachFixedDynamic(schema: schema, formula: try FormulaInfo.init(formula:formula, schema:schema))
    }
    
    func attachFixedDynamic(schema:Schema,formula:FormulaInfo) throws -> Schema{
        var res = schema
        let dynNodes:[Attribute:Set<String>] = formula.dynamicNodes

        for attr in dynNodes.keys{
            let cTax = self.attribute2ConfigTaxonomy[attr]!
            var tax = res.attribute2Taxonomy[attr]!
            try self.retriever.attachDynamic(config: cTax, tax: &tax,nodes:dynNodes[attr]!)
            let i = res.attributes.firstIndex(of: attr)
            res.attribute2Taxonomy[attr] = tax
            res.taxonomies[i!] = tax
        }
        return res
    }
}

extension ConfigSchema{
    public func getFullSchema(formula:String) throws -> Schema{
        let schema = try self.attachCommonChildren(schema:try self.getStaticSchema())
        let fInfo = try FormulaInfo.init(formula: formula, schema: schema)
        return try self.attachFixedDynamic(schema: schema,formula: fInfo)
    }
}



struct FormulaInfo{
    var dynamicNodes:[Attribute:Set<String>] = [:]
    var fixedNodes:[Attribute:Set<String>] = [:]
    enum NodeType:String{
        case fixed
        case dynamic
    }
    public init(formula:String,schema:Schema) throws {
       try getNodes(formula:formula,schema:schema)
    }
    
    private mutating func getNodes(formula:String,schema:Schema) throws {
        self.dynamicNodes = [:]
        self.fixedNodes = [:]
        
        let headAndClauses = formula.split(separator: "\n").map { String($0) }
        guard headAndClauses.count >= 1 else { throw ParserError.wrongNumberOfComponents(headAndClauses.count) }
        guard headAndClauses.count >= 2 else { return }
        for clauseString in headAndClauses[1...] {
            var uncommentedString = clauseString
        //^^^rimuovi eventuali commenti dalla stringa
            if let commentRange = clauseString.range(of: ParserStrings.commentMarker) {
                uncommentedString = String(clauseString.prefix(upTo: commentRange.lowerBound))
            }
            //^^^separa testa (numero clause) dal corpo
            let headAndBody = uncommentedString.split(separator: ParserStrings.clauseHeadBodySeparator).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if headAndBody.count != 2  { throw ParserError.wrongNumberOfComponents(headAndBody.count) }
        //^^^controlla se la preferenza è in forma semplice o standard
            guard headAndBody[0].firstIndex(of: ParserStrings.headVariableOpenMarker) != nil else {
                throw SchemaError.WrongGivenFormula(formula:formula,info:"the given formula is a simple formula, it must be a standard formula")
            }
            let parts = String(headAndBody[1]).split(separator: ParserStrings.andSymbol).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            for part in parts {
                let tupl = try self.getNodeAttr(part: part, schema: schema)
                if tupl.2 == NodeType.dynamic{
                    if self.dynamicNodes[tupl.1] == nil{
                        self.dynamicNodes[tupl.1] = Set()
                    }
                    self.dynamicNodes[tupl.1]!.insert(tupl.0)
                }else{
                    if self.fixedNodes[tupl.1] == nil{
                        self.fixedNodes[tupl.1] = Set()
                    }
                    self.fixedNodes[tupl.1]!.insert(tupl.0)
                }

            }
        }
    }
    
    private func getNodeAttr(part string:String,schema:Schema) throws -> (String,Attribute,NodeType){
        //^^^assegna il comparatore contenuto nella parte e dividi in base ad esso
        guard let foundComparator = ComparatorPredicate.allCases.filter({ string.firstIndex(of: $0.rawValue) != nil }).first else { throw ParserError.wrongSeparator(string) }
        let separator = foundComparator.rawValue
//        let separator: Character = string.firstIndex(of: "=") != nil ? "=" : "≠"
        let parts = string.split(separator: separator).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        if parts.count != 2 { throw ParserError.wrongNumberOfComponents(parts.count) }
        guard parts[0].firstIndex(of: ParserStrings.domainOpenMarker) != nil else { throw ParserError.wrongVariable(parts[0]) }
        // variabile[Attributo]
        let variableParts = parts[0].split(separator: ParserStrings.domainOpenMarker).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        if variableParts.count != 2 { throw ParserError.wrongNumberOfComponents(variableParts.count) }
        let attribute = variableParts[1].dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
        guard schema.attribute2Taxonomy[attribute] != nil else{
            throw FormulaError.AttributeNotInSchema(attribute: attribute)
        }
        let taxonomy = schema.attribute2Taxonomy[attribute]!
        guard taxonomy.valuesDictionary[parts[1]] == nil else{return (parts[1],attribute,NodeType.fixed)}
        return (parts[1],attribute,NodeType.dynamic)
    }
}


//lo so che e' orrendo ma di fatto cio' che fa l'inizializzatore va anche bene per aggiungere coppie a una tassonomia gia' formata ma non trovo un modo per riusare quel codice in maniera piu' elegante
extension Taxonomy {
    mutating func addValues(valuePairs: Set<ValuePair>, precomputed: Bool = false){
        for pair in valuePairs {
            self.valuesDictionary[pair.specific.name] = pair.specific
            self.valuesDictionary[pair.generic.name] = pair.generic
            
            var existingParents = self.parents[pair.specific.name] ?? []
            existingParents.insert(pair.generic.name)
            if existingParents.count > 1 {
                print("\(pair.specific.name) has parents: \(existingParents)")
            }
            self.parents[pair.specific.name] = existingParents

            self.nonMaximalValues.insert(pair.specific)
            self.maximalValues.remove(pair.specific)
            if !self.nonMaximalValues.contains(pair.generic) {
                self.maximalValues.insert(pair.generic)
            }

            var mst = self.moreSpecificThan[pair.generic] ?? []
            mst.insert(pair.specific)
            self.moreSpecificThan[pair.generic] = mst
        }
    
        let nonFunctionalNodeNames = self.parents.filter { $0.value.count > 1 }
        self.nonFunctionalNodes = Set(nonFunctionalNodeNames.keys.map { Value(name: $0) })
        logging {
            print("*** \(self.nonFunctionalNodes.count) non functional nodes")
        }

        if precomputed {
            self.transitivelyClosedAdjacencyLists = self.transitiveClosure(of: moreSpecificThan)
        }
    }
}
