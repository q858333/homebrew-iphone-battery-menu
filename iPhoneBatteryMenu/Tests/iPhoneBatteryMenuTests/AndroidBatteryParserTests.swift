import Testing
@testable import iPhoneBatteryMenu

struct AndroidBatteryParserTests {
    @Test func parsesChargingBatteryDump() throws {
        let dump = """
        Current Battery Service state:
          AC powered: false
          USB powered: true
          Wireless powered: false
          Max charging current: 500000
          status: 2
          health: 2
          present: true
          level: 83
          scale: 100
        """

        let status = try AndroidBatteryParser.parse(dump)

        #expect(status.level == 83)
        #expect(status.isCharging == true)
    }

    @Test func parsesDischargingBatteryDump() throws {
        let dump = """
        Current Battery Service state:
          status: 3
          level: 41
          scale: 100
        """

        let status = try AndroidBatteryParser.parse(dump)

        #expect(status.level == 41)
        #expect(status.isCharging == false)
    }
}
