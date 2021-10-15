//
//  TaxonomyRetriever.swift
//  SimplePreferencePropagation
//
//  Created by Dragos Mihaita Iftimie on 13/08/2021.
//

import PerfectMySQL
import Foundation

protocol TaxonomyRetriever{
    init(conn:ConnInfo)
    func getConnInfo() -> ConnInfo
    func getStaticTaxonomy(config:ConfigTaxonomy) throws -> Taxonomy
    func attachDynamic(config:ConfigTaxonomy,tax: inout Taxonomy,nodes:Set<String>) throws

    func getSimpleIntersections(taxonomy: inout LightTaxonomy,config:ConfigTaxonomy) throws
}

public struct MyTaxonomyRetriever:TaxonomyRetriever{
    
    let dbTalker:DbTalker
    let connInfo:ConnInfo
    
    init(conn: ConnInfo) {
        self.dbTalker = DbTalker.init(connInfo: conn)
        self.connInfo = conn
    }
    
    func getConnInfo() -> ConnInfo {
        return self.connInfo
    }
    
    
    public func attachDynamic(config: ConfigTaxonomy, tax: inout Taxonomy,nodes:Set<String>) throws {
        
        var tmpVals:Set<ValuePair>
        var resVals:Set<ValuePair> = Set<ValuePair>()
        
        if let qBConfig = config as? QueryBasedConfigTax {
            for node in nodes{
                for query in qBConfig.getQueries4Leaves(leaf: node){
                    tmpVals = try self.dbTalker.getValues(query: query)
                    if(tmpVals.count == 0){
                        throw FormulaError.DynamicNodeNotFound(node: node)
                    }
                    resVals = resVals.union(tmpVals)
                }
            }
        }
        
        
        if let iBConfig = config as? RuleBasedConfigTax{
            for node in nodes{
                tmpVals = Set<ValuePair>(try iBConfig.getFathers(leaf: node).map(){ValuePair.init(specific: Value.init(name: node), generic: $0)})
                resVals = resVals.union(tmpVals)
            }
        }
        tax.addValues(valuePairs: resVals)
    }
    
    public func getSimpleIntersections(taxonomy: inout LightTaxonomy,config:ConfigTaxonomy) throws{
         if let qBConfig = config as? QueryBasedConfigTax{
             var query:String = ""
             for node1 in taxonomy.nodes{
                 for node2 in taxonomy.nodes{
                     if node1 == node2 || taxonomy.doIntersect(parents: Set<String>([node1,node2])){
                         continue
                     }
                     query = qBConfig.getQuery4CommonChildren(nodes: Set<String>([node1,node2]))
                    if try self.dbTalker.count(query: query) >= 1{
                         taxonomy.addIntersection(parents: Set<String>([node1,node2]))
                     }
                 }
             }
         }
         if let iBConfig = config as? RuleBasedConfigTax{
             for node1 in taxonomy.nodes{
                 for node2 in taxonomy.nodes{
                     if node1 == node2 || taxonomy.doIntersect(parents: Set<String>([node1,node2])){
                         continue
                     }
                     if try iBConfig.getRuleByValue(value: node1).areIntersecating(other: iBConfig.getRuleByValue(value: node2)){
                         taxonomy.addIntersection(parents: Set<String>([node1,node2]))
                         
                     }
                 }
             }
         }
     }
     
     public func getStaticTaxonomy(config:ConfigTaxonomy) throws -> Taxonomy {
         var res:Taxonomy = try Taxonomy(flat:"")

         if let qBConfig = config as? QueryBasedConfigTax {
            var tmpVals:Set<ValuePair> = Set<ValuePair>()
             for query in qBConfig.getQueries4Fixed(){
                tmpVals = tmpVals.union(try self.dbTalker.getValues(query: query))
             }
            res = Taxonomy.init(valuePairs: tmpVals)
         }
         if let iBConfig = config as? RuleBasedConfigTax{
            let result:Set<ValuePair> = Set<ValuePair>(iBConfig.getStaticValues().map({val in return ValuePair.init(specific: Value.init(name: val), generic: .topValue)}))
            res = Taxonomy.init(valuePairs: result)
         }
         return res
     }
    
    private func getLastLevel(levels:String) -> [String]{
        let splitted = levels.split(separator: "\n")
        let lastLvl:String
        if splitted.count == 1{
            lastLvl = splitted[0].split(separator: ":")[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }else{
            lastLvl = splitted[splitted.count - 1].split(separator: ":")[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return lastLvl.components(separatedBy: "--").map(){$0.trimmingCharacters(in: .whitespacesAndNewlines)}
    }
}

public enum ConnError:Error{
    case ConnectionError
    case DbNotResponding
    case QueryRaisedError(query:String)
}

public class DbTalker{
    var db:MySQL = MySQL.init()
    let info:ConnInfo
    init(connInfo:ConnInfo){
        self.info = connInfo
    }
    
    private func deconnect(){
        self.db.close()
        self.db = MySQL.init()
    }
    
    private func connect() throws {
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
    func getValues(query:String) throws -> Set<ValuePair> {
        var res:Set<ValuePair> = Set<ValuePair>()
        try self.connect()
        let results = try self.execQuery(query: query)
            results.forEachRow {
                row in
                if row.count == 1 {
                    res.insert(ValuePair.init(specific: Value.init(name: row[0]!), generic: .topValue))
                }else if row.count == 2{
                    res.insert(ValuePair.init(specific: Value.init(name: row[0]!), generic: Value.init(name: row[1]!)))
                }
                //cosa fare in caso non previsto?
            }
        self.deconnect()
        return res
    }
    private func execQuery(query:String) throws -> MySQL.Results{
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

struct ConnInfo{
    let host:String
    let user:String
    let port:String? //port == nil indica l uso della porta di default
    let password:String
    let database:String
    
    init(user us:String,host hs:String,port pr:String? = nil, password ps:String,database db:String){
        self.host = hs
        self.user = us
        self.port = pr
        self.password = ps
        self.database = db
    }
}

public struct LightTaxonomy{
    public var intersections:[Set<String>] = []
    public var nodes:Set<String>
    public init(nodes:Set<String>){
        self.nodes = nodes
        for node in self.nodes{
            if node == Value.topValueName{
                self.nodes.remove(node)
            }
        }
    }
    
    public func getValues() -> Set<ValuePair>{
        var res:Set<ValuePair> = Set<ValuePair>()
        let count:PlaceholderCounter = PlaceholderCounter.init()
        for intersection in intersections{
            let child = count.getActual()
            for value in intersection{
                let pair:ValuePair = ValuePair.init(specific: Value.init(name: child), generic: Value.init(name: value))
                res.insert(pair)
            }
        }
        
        
        return res
    }
    
    public mutating func removeUselessIntersections(){
        var toRemove:Set<Set<String>> = Set<Set<String>>()
        for intersection1 in self.intersections{
            for intersection2 in self.intersections{
                if intersection2 == intersection1{
                    continue
                }
                if intersection1.isSubset(of: intersection2){
                    toRemove.insert(intersection1)
                }
            }
        }
        for int in toRemove{
            intersections.remove(at: intersections.firstIndex(of: int)!)
        }
    }
    
    public mutating func addILevelIntersections(level:Int) {
        if level > nodes.count{
            return
        }
        for combination in nodes.combinations(ofCount: level){
            if self.doIntersect(parents: Set<String>(combination)){
                continue
            }
            
            var toAdd = true
            for elem1 in combination{
                for elem2 in combination{
                    if elem1 == elem2{
                        continue
                    }
                    if !self.doIntersect(parents: Set<String>([elem1,elem2])){
                        toAdd = false
                    }
                }
            }
            if toAdd{
                self.addIntersection(parents: Set<String>(combination))
            }
        }
    }
    
    public mutating func removeUnusedNodes(index:Int){
        var stopIterations:Bool = false
        while(!stopIterations){
            var nodeRemoved = false
            for node in nodes{
                var occurrencies:Int = 0
            
                for intersection in self.intersections.filter({$0.count == 2}){
                    if intersection.contains(node) && intersection.isSubset(of: self.nodes){
                        occurrencies = occurrencies + 1
                    }
                }
                if occurrencies < index{
                    nodeRemoved = true
                    self.nodes.remove(node)
                }
            }
            if !nodeRemoved {
                stopIterations = true
            }
        }
        
    }
    
    public func doIntersect(parents:Set<String>) -> Bool{
        var res = false
        for intersection in intersections{
            if intersection == parents{
                res = true
                break
            }
        }
        return res
    }
    
    public mutating func addIntersection(parents:Set<String>){
        if !self.doIntersect(parents: parents){
            self.intersections.append(parents)
        }
    }
}

class PlaceholderCounter{
     var index:Int
     static let placeholder:String = "PLACEHOLDER"
     init(){
         self.index = 0
     }
    func reset(){
        self.index = 0
    }
    
    private func increase(){
        self.index = self.index + 1
    }
 
     func getActual() -> String{
        let res = PlaceholderCounter.placeholder + String(self.index)
        self.increase()
        return res
     }
 }

