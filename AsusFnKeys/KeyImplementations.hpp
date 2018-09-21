//
//  KeyImplementations.hpp
//  AsusFnKeys
//
//  Copyright © 2018 Le Bao Hiep. All rights reserved.
//

#ifndef KeyImplementations_hpp
#define KeyImplementations_hpp

#include <libkern/libkern.h>
#include <VirtualSMCSDK/kern_vsmcapi.hpp>
#include <IOKit/acpi/IOACPIPlatformDevice.h>

class ALSForceBits : public VirtualSMCValue {
public:
    /**
     *  Each "1" bit in gui8ALSForced indicates that a certain writable ALS
     *  variable has been overridden (i.e., forced) by the host OS or
     *  host diagnostics, and that variable should not be written by the SMC
     *  again until the applicable bit is cleared in gui8ALSForced.
     *  Currently, the used bits are:
     *      Bit 0 protects gui16ALSScale
     *      Bit 1 protects ui16Chan0 and ui16Chan1 of aalsvALSData
     *      Bit 2 protects gui16ALSLux
     *      Bit 3 protects fHighGain of aalsvALSData
     *      Bit 4 protects gai16ALSTemp[MAX_ALS_SENSORS]
     *  All other bits are reserved and should be cleared to 0.
     */
    enum {
        kALSForceScale      = 1,
        kALSForceChan       = 2,
        kALSForceLux        = 4,
        kALSForceHighGain   = 8,
        kALSForceTemp       = 16
    };
    
    uint8_t bits() { return data[0]; }
};

class SMCALSValue : public VirtualSMCValue {
    _Atomic(uint32_t) *currentLux;
    ALSForceBits *forceBits;
protected:
    SMC_RESULT readAccess() override;
    
public:
    /**
     *  Contains latest ambient light info from 1 sensor
     */
    struct PACKED Value {
        /**
         *  If TRUE, data in this struct is valid.
         */
        bool valid {false};
        
        /**
         *  If TRUE, ui16Chan0/1 are high-gain readings.
         *  If FALSE, ui16Chan0/1 are low-gain readings.
         */
        bool highGain {true};
        
        /**
         *  I2C channel 0 data or analog(ADC) data.
         */
        uint16_t chan0 {0};
        
        /**
         *  I2C channel 1 data.
         */
        uint16_t chan1 {0};
        
        /**
         * The following field only exists on systems that send ALS change notifications to the OS:
         * Room illumination in lux, FP18.14.
         */
        uint32_t roomLux {0};
    };
    
    SMCALSValue(_Atomic(uint32_t) *currentLux, ALSForceBits *forceBits) :
    currentLux(currentLux), forceBits(forceBits) {}
};

class SMCKBrdBLightValue : public VirtualSMCValue {
protected:
    IOACPIPlatformDevice *atkDevice {nullptr};
    SMC_RESULT writeAccess() override;
public:
    /**
     *  Keyboard backlight brightness
     */
    struct lks {
        uint8_t unknown0 {0};
        uint8_t unknown1 {1};
    };
    struct lkb {
        uint8_t val1 {0};
        uint8_t val2 {1};
        // maximum keyboard backlight value is 0xfff, stored in 12 bits
        // the first 8 bits are stored in val1
        // the rest 4 bits are stored in val2 (bit 7->4)
        // eg. value is 0x6eb, lkb would be 6e b0
    };
    
    SMCKBrdBLightValue(IOACPIPlatformDevice *atkDevice): atkDevice(atkDevice) {}
};

#endif /* KeyImplementations_hpp */
