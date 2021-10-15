//
//  ResultAlgorithmConfig.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Mihaita Iftimie on 18/09/2021.
//
import PerfectMySQL
import Foundation


protocol ResultTemplate{
    func getQuery(staticNode:String) -> String
}

enum ConfigResultAlgorithmError:Error{
    case AttributesDoNotMatch
    case UnknownTaxonomyTypeOfAttribute(attribute:Attribute)
    case ResponseFromDatabaseHasDifferentNumberOfColumnsThanDeclared(query:String)
    case RuleBasedAttributesAndGivenRulesForEachAttributeDoNotMatch
    case QueryBasedAttributesAndGivenTemplatesForEachAttributeDoNotMatch
}

public class DBTalkerComponent{
    var db:MySQL = MySQL.init()
    let info:ConnInfo
    init(connInfo:ConnInfo){
        self.info = connInfo
    }
    
     func deconnect(){
        self.db.close()
        self.db = MySQL.init()
    }
    
     func connect() throws {
        let connected = db.connect(host: self.info.host, user: self.info.user, password: self.info.password, db: self.info.database)
        guard connected else {
            // verify we connected successfully
            throw ConnError.ConnectionError
        }
    }
    
    func count(query:String) throws -> Int{
        try self.connect()
        let result = try self.execQuery(query:query)
        let row1 = result.next()!
        self.deconnect()
        return Int.init(row1[0]!)!
    }

    func execQuery(query:String) throws -> MySQL.Results{
        if !db.ping() {
            throw ConnError.DbNotResponding
        }
        let querySuccess = db.query(statement: query)
        // make sure the query worked
        guard querySuccess else {
            throw ConnError.QueryRaisedError(query:query)
        }
        return db.storeResults()!
    }
}

struct ResultDBServices{
    let DB:DBTalkerComponent
    let columns:Int
    public init(connInfo:ConnInfo,columns:Int){
        self.columns = columns
        self.DB = DBTalkerComponent.init(connInfo: connInfo)
    }
    
    func getDinamic(query:String) throws -> Set<Value>{
        try DB.connect()
        var result = Set<Value>()
        let response = try self.DB.execQuery(query: query)
        response.forEachRow(callback: {
            row in
            result.insert(Value.init(name: row[0]!))
        })
        DB.deconnect()
        return result
    }
    func isDinamic(query:String) throws -> Bool{
        return try self.DB.count(query: query) > 0
    }
    func getTuples(query:String) throws -> Set<Tuple>{
        print(query)
        var result = Set<Tuple>()
        try DB.connect()
        let response = try self.DB.execQuery(query: query)
        if response.numFields() != self.columns{
            throw ConfigResultAlgorithmError.ResponseFromDatabaseHasDifferentNumberOfColumnsThanDeclared(query: query)
        }
        
        response.forEachRow(callback: {
            row in
            var tuple:[Value] = []
            for i in (0...self.columns-1){
                tuple.append(Value.init(name: row[i]!))
            }
            result.insert(tuple)
        })
        DB.deconnect()
        return result
    }
}

struct ConfigResultAlgorithm{
    let DBServices:ResultDBServices
    let tRelationName:String
    let attrToTaxType:[Attribute:ConfigTaxonomy.Type]
    let attrToTemplates:[Attribute:[ResultTemplate]]
    let attributeOrdering:[Attribute]
    let ruledAttributes:[Attribute:RuleBasedConfigTax]
    public init(attributeOrdering:[Attribute],connInfo:ConnInfo,tRelationName:String,attrToTaxType:[Attribute:ConfigTaxonomy.Type],attributesToTemplates:[Attribute:[ResultTemplate]],attributesToRules:[Attribute:RuleBasedConfigTax]) throws{
        if  Set<Attribute>(attributeOrdering) != Set<Attribute>(attrToTaxType.keys){
            throw ConfigResultAlgorithmError.AttributesDoNotMatch
        }
        
        self.ruledAttributes = attributesToRules
        self.attributeOrdering = attributeOrdering
        self.DBServices = .init(connInfo: connInfo,columns:attributeOrdering.count)
        self.tRelationName = tRelationName
        self.attrToTaxType = attrToTaxType
        self.attrToTemplates = attributesToTemplates
        if Set<Attribute>(attrToTaxType.filter({$0.value == QueryBasedConfigTax.self}).keys) != Set<Attribute>(attrToTemplates.keys){
            throw ConfigResultAlgorithmError.QueryBasedAttributesAndGivenTemplatesForEachAttributeDoNotMatch
        }
        if Set<Attribute>(attrToTaxType.filter({$0.value == RuleBasedConfigTax.self}).keys) != Set<Attribute>(ruledAttributes.keys){
            throw ConfigResultAlgorithmError.RuleBasedAttributesAndGivenRulesForEachAttributeDoNotMatch
        }
    }
    
    func getDinamic(staticNode:Value,attribute:Attribute) throws -> Set<Value>{
        var result = Set<Value>()
        if self.attrToTaxType[attribute] == nil {
            throw ConfigResultAlgorithmError.UnknownTaxonomyTypeOfAttribute(attribute: attribute)
        }
        
        if self.attrToTaxType[attribute]! == RuleBasedConfigTax.self{
            let tmpRes = try self.DBServices.getDinamic(query: "select distinct \(attribute) from \(self.tRelationName);")
            let configTax = self.ruledAttributes[attribute]!
            for value in tmpRes{
                if try configTax.getFathers(leaf: value.name).contains(staticNode){
                    result.insert(value)
                }
            }
        }else if self.attrToTaxType[attribute]! == QueryBasedConfigTax.self{
            for template in self.attrToTemplates[attribute]!{
                result = result.union(try self.DBServices.getDinamic(query: template.getQuery(staticNode: staticNode.name)))
            }
            
        }
        return result
        
    }
    
    func isDinamic(node:Value,attribute:Attribute) throws -> Bool{
        let query = "select count(*) from \(self.tRelationName) where \(attribute) = '\(node.name)';"
        return try self.DBServices.isDinamic(query: query)
    }
    
    func getTuples(queryNodes:PreQueryNode) throws -> TuplesResult{
        for node in queryNodes.values{
            if node.value.isEmpty{
                return TuplesResult.init(tuples: Set<Tuple>())
            }
        }
        let attributes = " " + self.attributeOrdering.joined(separator: ",") + " "
        let conditions = queryNodes.values.map({" \($0.attribute) in ('\(Array<Value>($0.value).map({$0.name}).joined(separator: "','"))')"})
        return TuplesResult.init(tuples: try self.DBServices.getTuples(query: "select distinct \(attributes) from \(self.tRelationName) where \(conditions.joined(separator: " AND "));"))
    }
}
