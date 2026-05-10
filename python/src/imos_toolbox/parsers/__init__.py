"""Parser framework and parser implementations."""

from imos_toolbox.parsers.base import BaseParser
from imos_toolbox.parsers.aquatec import AquatecParser
from imos_toolbox.parsers.dr1050 import DR1050Parser
from imos_toolbox.parsers.ecobb9 import ECOBB9Parser
from imos_toolbox.parsers.ecotriplet import ECOTripletParser
from imos_toolbox.parsers.niwa import NIWAParser
from imos_toolbox.parsers.rcm import RCMParser
from imos_toolbox.parsers.registry import ParserRegistry, load_instrument_parser_map
from imos_toolbox.parsers.sbe19 import SBE19Parser
from imos_toolbox.parsers.sbe26 import SBE26Parser
from imos_toolbox.parsers.sbe37 import SBE37Parser
from imos_toolbox.parsers.sbe37sm import SBE37SMParser
from imos_toolbox.parsers.sbe39 import SBE39Parser
from imos_toolbox.parsers.sbe56 import SBE56Parser
from imos_toolbox.parsers.sensus_ultra import SensusUltraParser
from imos_toolbox.parsers.starmon_dst import StarmonDSTParser
from imos_toolbox.parsers.starmon_mini import StarmonMiniParser
from imos_toolbox.parsers.vemco import VemcoParser
from imos_toolbox.parsers.wetstar import WetStarParser
from imos_toolbox.parsers.wqm import WQMParser
from imos_toolbox.parsers.xr import XRParser
from imos_toolbox.parsers.ysi6series import YSI6SeriesParser

__all__ = [
	"BaseParser",
	"AquatecParser",
	"DR1050Parser",
	"ECOBB9Parser",
	"ECOTripletParser",
	"NIWAParser",
	"RCMParser",
	"ParserRegistry",
	"SBE19Parser",
	"SBE26Parser",
	"SBE37Parser",
	"SBE37SMParser",
	"SBE39Parser",
	"SBE56Parser",
	"SensusUltraParser",
	"StarmonDSTParser",
	"StarmonMiniParser",
	"VemcoParser",
	"WetStarParser",
	"WQMParser",
	"XRParser",
	"YSI6SeriesParser",
	"load_instrument_parser_map",
]
