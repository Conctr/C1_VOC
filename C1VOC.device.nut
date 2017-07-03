// Copyright (c) 2017 Mystic Pants Pty Ltd
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

// Import Libraries
#require "conctr.device.class.nut:1.0.0"
#require "CRC16.class.nut:1.0.0"
 
 
// Constants
const REG_READING = "";
const CMD_STATUS = "\x0C\x00\x00\x00\x00";

class VOCSensor{
    _i2c = null;
    _addr = 0xE0;
    
    constructor(i2c) {
        _i2c = i2c;        
    }
    
    function readStatus() {
        // Send Request
        local readingRequest = blob(6);
        readingRequest.writestring(CMD_STATUS);
        readingRequest.writen(_calcCRC(readingRequest), 'c');
        _send(readingRequest.tostring());
        
        imp.wakeup(0.1, function() {

            local result = _i2c.read(_addr, REG_READING, 7);
            if (result == null) {
                throw "I2C read error: " + _i2c.readerror();
            } else if (result == "") {
                // Empty string
            } else {
                local data = _parseFrame(result);
                if (data != null) {
                    local VOC = (data[0] - 13) * (1000.0/229); // ppb: 0 .. 1000
                    local CO2 = (data[1] - 13) * (1600.0 / 229) + 400; // ppm: 400 .. 2000

                    server.log("VOC: " + VOC + " CO2: " + CO2);
                    //server.log("Receiving");
                    //server.log(data);
                    //local ResistorValue = 10 * (data[4] + (256 * data[3]) + (65536 * data[2]));
                    //server.log(ResistorValue+ "ohms");
                }
            }
        }.bindenv(this));
    }
    
    function _parseFrame(data) {
        local body = blob(6);
        body.writestring(data.tostring().slice(0,6))
        
        // Verify CRC
        if (_calcCRC(body) == data[6]) {
           return body; 
        } else {           
            return null;
        }
    }
    
    function _send(message) {
        _i2c.write(_addr, message);
    }
    
    function _calcCRC(inputBlob) {
        local crc = 0x00;
        local sum = 0x0000;
        
        // Loop over inputBlob
        for (local i = 0; i < inputBlob.len(); i++) {
            sum = crc + inputBlob[i];
            crc = 0x00FF & sum;
            crc += (sum / 0x100);
        }
        // complement
        crc = 0xFF - crc; 
        
        return crc; 
    }
    
}
    
    
function readVOC() {
    voc.readStatus();
    imp.wakeup(1, readVOC.bindenv(this));
}


//=============================================================================
// START OF PROGRAM

// Setup Conctr
conctr <- Conctr({"sendLoc": false});

// Initialise pins
onewire_en <- hardware.pinS;
onewire_en.configure(DIGITAL_OUT, 1);
ext_i2c <- hardware.i2cFG;
ext_i2c.configure(CLOCK_SPEED_100_KHZ);

// Initialise VOC
voc <- VOCSensor(ext_i2c);

// Start Polling after 2 seconds
imp.sleep(2);
readVOC();

