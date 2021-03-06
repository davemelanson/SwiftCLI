import XCTest
@testable import SwiftCLITests

XCTMain([
	 testCase(ArgumentListManipulatorTests.allTests),
	 testCase(ArgumentListTests.allTests),
	 testCase(CompletionGeneratorTests.allTests),
	 testCase(HelpMessageGeneratorTests.allTests),
	 testCase(OptionParserTests.allTests),
     testCase(OptionRegistryTests.allTests),
	 testCase(ParameterFillerTests.allTests),
     testCase(RouterTests.allTests),
     testCase(SwiftCLITests.allTests)
])
