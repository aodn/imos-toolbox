package org.imos.ddb;

import java.io.File;
import java.io.IOException;
//imports from Jackcess Encrypt
import com.healthmarketscience.jackcess.CryptCodecProvider;
import com.healthmarketscience.jackcess.Database;

import net.ucanaccess.jdbc.JackcessOpenerInterface;

public class CryptCodecOpener implements JackcessOpenerInterface {
	public Database open(File fl, String pwd) throws IOException {
		return Database.open(fl, true, true, null, null, new CryptCodecProvider(pwd));
	}
	//Notice that third parameter (autosync =true) is recommended with UCanAccess for performance reasons.
	//For more details about autosync parameter (and related tradeoff), see the Jackcess documentation.
}
