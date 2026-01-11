import Foundation
import SQLite3

struct XCResultContext {
    let database: SQLiteDatabase
    let action: ActionRow
    let testPlanRuns: [TestPlanRunRow]

    init(xcresultPath: String) throws {
        let databasePath = XCResultContext.databasePath(for: xcresultPath)
        self.database = try SQLiteDatabase(path: databasePath)
        guard let action = try XCResultContext.fetchAction(from: database) else {
            throw SQLiteError("No Actions rows found in \(databasePath).")
        }
        self.action = action
        self.testPlanRuns = try XCResultContext.fetchTestPlanRuns(from: database, actionId: action.id)
    }

    func fetchRunDestination(runDestinationId: Int?) throws -> RunDestinationRow? {
        guard let runDestinationId else { return nil }
        let sql = "SELECT rowid, name, architecture, device_fk FROM RunDestinations WHERE rowid = ?;"
        return try database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(runDestinationId))
        }) { statement in
            RunDestinationRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? "",
                architecture: SQLiteDatabase.string(statement, 2) ?? "",
                deviceId: SQLiteDatabase.int(statement, 3) ?? 0
            )
        }
    }

    func fetchConfiguration(configurationId: Int) throws -> ConfigurationRow {
        let sql = "SELECT rowid, name FROM TestPlanConfigurations WHERE rowid = ?;"
        let configuration = try database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(configurationId))
        }) { statement in
            ConfigurationRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? ""
            )
        }
        return configuration ?? ConfigurationRow(id: configurationId, name: "")
    }

    func fetchConfigurations() throws -> [ConfigurationRow] {
        let sql = "SELECT rowid, name FROM TestPlanConfigurations ORDER BY rowid;"
        return try database.query(sql) { statement in
            ConfigurationRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? ""
            )
        }
    }

    func fetchDevice(deviceId: Int) throws -> DeviceRow? {
        let sql = """
        SELECT rowid, identifier, name, modelName, operatingSystemVersion,
               operatingSystemVersionWithBuildNumber, platform_fk
        FROM Devices
        WHERE rowid = ?;
        """
        return try database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(deviceId))
        }) { statement in
            DeviceRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                identifier: SQLiteDatabase.string(statement, 1) ?? "",
                name: SQLiteDatabase.string(statement, 2) ?? "",
                modelName: SQLiteDatabase.string(statement, 3) ?? "",
                operatingSystemVersion: SQLiteDatabase.string(statement, 4) ?? "",
                operatingSystemVersionWithBuildNumber: SQLiteDatabase.string(statement, 5) ?? "",
                platformId: SQLiteDatabase.int(statement, 6) ?? 0
            )
        }
    }

    func fetchPlatform(platformId: Int) throws -> PlatformRow? {
        let sql = "SELECT rowid, userDescription FROM Platforms WHERE rowid = ?;"
        return try database.queryOne(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(platformId))
        }) { statement in
            PlatformRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                userDescription: SQLiteDatabase.string(statement, 1) ?? ""
            )
        }
    }

    private static func databasePath(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        if url.pathExtension == "xcresult" {
            return url.appendingPathComponent("database.sqlite3").path
        }
        if url.lastPathComponent == "database.sqlite3" {
            return url.path
        }
        return url.appendingPathComponent("database.sqlite3").path
    }

    private static func fetchAction(from database: SQLiteDatabase) throws -> ActionRow? {
        let sql = """
        SELECT Actions.rowid,
               Actions.name,
               Actions.started,
               Actions.finished,
               Actions.runDestination_fk,
               Actions.host_fk,
               Actions.testPlan_fk,
               Invocations.scheme,
               TestPlans.name
        FROM Actions
        JOIN Invocations ON Invocations.rowid = Actions.invocation_fk
        JOIN TestPlans ON TestPlans.rowid = Actions.testPlan_fk
        ORDER BY Actions.orderInInvocation
        LIMIT 1;
        """
        return try database.queryOne(sql) { statement in
            ActionRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                name: SQLiteDatabase.string(statement, 1) ?? "",
                started: SQLiteDatabase.double(statement, 2) ?? 0,
                finished: SQLiteDatabase.double(statement, 3) ?? 0,
                runDestinationId: SQLiteDatabase.int(statement, 4),
                hostDeviceId: SQLiteDatabase.int(statement, 5),
                testPlanId: SQLiteDatabase.int(statement, 6) ?? 0,
                scheme: SQLiteDatabase.string(statement, 7) ?? "",
                testPlanName: SQLiteDatabase.string(statement, 8) ?? ""
            )
        }
    }

    private static func fetchTestPlanRuns(from database: SQLiteDatabase, actionId: Int) throws -> [TestPlanRunRow] {
        let sql = """
        SELECT rowid, configuration_fk, orderInAction
        FROM TestPlanRuns
        WHERE action_fk = ?
        ORDER BY orderInAction;
        """
        return try database.query(sql, binder: { statement in
            sqlite3_bind_int(statement, 1, Int32(actionId))
        }) { statement in
            TestPlanRunRow(
                id: SQLiteDatabase.int(statement, 0) ?? 0,
                configurationId: SQLiteDatabase.int(statement, 1) ?? 0,
                orderInAction: SQLiteDatabase.int(statement, 2) ?? 0
            )
        }
    }
}

struct ActionRow {
    let id: Int
    let name: String
    let started: Double
    let finished: Double
    let runDestinationId: Int?
    let hostDeviceId: Int?
    let testPlanId: Int
    let scheme: String
    let testPlanName: String
}

struct TestPlanRunRow {
    let id: Int
    let configurationId: Int
    let orderInAction: Int
}

struct RunDestinationRow {
    let id: Int
    let name: String
    let architecture: String
    let deviceId: Int
}

struct ConfigurationRow {
    let id: Int
    let name: String
}

struct DeviceRow {
    let id: Int
    let identifier: String
    let name: String
    let modelName: String
    let operatingSystemVersion: String
    let operatingSystemVersionWithBuildNumber: String
    let platformId: Int
}

struct PlatformRow {
    let id: Int
    let userDescription: String
}
