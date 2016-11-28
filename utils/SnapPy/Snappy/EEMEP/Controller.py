'''
Created on Aug 9, 2016

@author: heikok
'''

import sys
import os
import re
import datetime
import json
from collections import deque
from time import gmtime, strftime
from Snappy.BrowserWidget import BrowserWidget
from Snappy.EEMEP.Resources import Resources
from PyQt5 import QtWidgets

def debug(*objs):
    print("DEBUG: ", *objs, file=sys.stderr)

def tail(f, n):
    lines = deque(maxlen=n)
    with open(f) as fh:
        for line in fh:
            lines.append(line)
    return "".join(lines)


class Controller():
    '''
    Controller for EEMEP Widget. Starts the browserwidget as self.main and connects it to the form handler
    '''


    def __init__(self):
        '''
        Initialize Widget annd handlers
        '''
        self.res = Resources()
        self.main = BrowserWidget()
        self.main.set_html(self.res.getStartScreen())
        self.main.set_form_handler(self._create_snap_form_handler())
        self.main.show()
        self.eemepRunning = "inactive"
        self.lastOutputDir = ""
        self.lastQDict = {}

    def write_log(self, txt:str):
        debug(txt)
        self.main.evaluate_javaScript('updateSnapLog({0});'.format(json.dumps(txt)))

    def update_log_query(self, qDict):
        #MainBrowserWindow._default_form_handler(qDict)
        self.write_log("updating...")
        if os.path.isfile(os.path.join(self.lastOutputDir,"snap.log.stdout")) :
            lfh = open(os.path.join(self.lastOutputDir,"snap.log.stdout"))
            debug(tail(os.path.join(self.lastOutputDir,"snap.log.stdout"),30))
            self.write_log(tail(os.path.join(self.lastOutputDir,"snap.log.stdout"), 30))
            lfh.close()

    def _create_snap_form_handler(self):
        def handler(queryDict):
            """a form-handler with closure for self"""
            options = { 'Run' : self.run_eemep_query,
                        'Update' : self.update_log_query
            }
            # mapping from QList<QPair> to simple dictionary
            qDict = dict()
            for key, value in queryDict:
                qDict[key] = value
            # calling the correct handler depending on the module
            try:
                options[qDict['action']](qDict)
            except TypeError as ex:
                self.write_log("type-error: {}".format(ex))
            except ValueError as ex:
                self.write_log("value-error: {}".format(ex))
            except:
                self.write_log("Unexpected error on {0}: {1}".format(qDict['action'],sys.exc_info()[0]))
                raise
        return handler

    def run_eemep_query(self, qDict):
        # make sure all files are rw for everybody (for later deletion)
        os.umask(0)
        debug("run_eemep_query")
        for key, value in qDict.items():
            print(str.format("{0} => {1}", key, value))
        errors = ""
        match = re.search(r'(\d{4})-(\d{2})-(\d{2})[\+\s]+(\d{1,2})', qDict['startTime'])
        if match:
            startTime = "{0} {1} {2} {3}".format(*match.group(1,2,3,4))
            startDT = datetime.datetime(*tuple(map(int, list(match.group(1,2,3,4)))))
            modelStartDT = datetime.datetime(startDT.year, startDT.month, startDT.day, 0, 0, 0)
        else:
            errors += "Cannot interpret startTime: {0}\n".format(qDict['startTime'])

        try:
            runTime = int(qDict['runTime'])
        except:
            errors += "Cannot interpret runTime: {}\n".format(qDict['runTime'])


        if qDict['volcanotype'] == 'default':
            type = 'M0'
        else:
            type = qDict['volcanotype']
        tag = "latlon"
        volcanoes = self.res.readVolcanoes()
        if (qDict['volcano'] and volcanoes[qDict['volcano']]):
            tag = qDict['volcano']
            volcano = volcanoes[qDict['volcano']]['NAME']
            latf = volcanoes[qDict['volcano']]['LATITUDE']
            lonf = volcanoes[qDict['volcano']]['LONGITUDE']
            altf = volcanoes[qDict['volcano']]['ELEV']
            if qDict['volcanotype'] == 'default':
                type = volcanoes[qDict['volcano']]['ERUPTIONTYPE']
        else:
            lat = qDict['latitude']
            lon = qDict['longitude']
            alt = qDict['altitude']
            volcano = "{lat}N_{lon}E".format(lat=lat, lon=lon)
            try:
                latf = float(lat)
                lonf = float(lon)
                altf = float(alt)
            except:
                latf = 0.
                lonf = 0.
                altf = 0.
                errors += "Cannot interpret latitude/longitude/altitude: {0}/{1}/{2}\n".format(lat,lon,alt);

        if (abs(latf) > 90):
            errors += "latitude {0} outside bounds\n".format(latf)
        if (abs(lonf) > 180):
            errors += "longitude {0} outside bounds\n".format(lonf)
        debug("volcano: {0} {1:.2f} {2:.2f} {3} {4}".format(volcano, latf, lonf, altf, type))
        tag = re.sub(r'[^\w_-]', '', tag)
        self.lastTag = "{0} {1}".format(tag, startTime)

        if (len(errors) > 0):
            debug('updateLog("{0}");'.format(json.dumps("ERRORS:\n\n"+errors)))
            self.write_log("ERRORS:\n\n{0}".format(errors))
            return
        self.write_log("working with lat/lon=({0}/{1}) starting at {2}".format(latf, lonf, startTime))

        types = self.res.readVolcanoTypes()
        cheight = float(types[type]['H']) * 1000 # km -> m
        rate = float(types[type]['dM/dt'])
        try:
            if qDict['cloudheight']:
                cheight = float(qDict['cloudheight'])
                # rate in kg/s from Mastin et al. 2009, formular (1) and a volume (DRE) (m3) to
                # mass (kg) density of 2500kg/m3
                rate = 2500.* ((.5*cheight/1000)**(1/0.241))
        except:
            errors += "cannot interpret cloudheight (m): {0}\n".format(qDict['cloudheight'])
        eruptions = []
        eruption = '<eruption start="{start}Z" end="{end}Z" bottom="{bottom:.0f}" top="{top:.0f}" rate="{rate:.0f}" m63="{m63:.2f}"/>'
        eruptions.append(eruption.format(start=startDT.isoformat(),
                                         end=(startDT + datetime.timedelta(hours=runTime)).isoformat(),
                                         bottom=0,
                                         top=cheight,
                                         rate=rate,
                                         m63=types[type]['m63']))

        self.lastOutputDir = os.path.join(self.res.getOutputDir(), "{0}".format(tag))
        self.lastQDict = qDict
        sourceTerm = """<?xml version="1.0" encoding="UTF-8"?>
<volcanic_eruption_run run_time_hours="{runTime}" output_directory="{outdir}">
<model_setup use_restart_file="restart">
   <!-- reference_date might also be best_estimate, e.g. mix latest forecasts -->
   <weather_forecast reference_date="{model_run}" model_start_time="{model_start_time}Z"/>
</model_setup>
<volcano name="{volcano}" lat="{lat}" lon="{lon}" altitude="{alt:.0f}" />
<eruptions>
<!-- bottom and top of ash-cloud in m above ground -->
<!-- rate in kg/s -->
{eruptions}
</eruptions>

</volcanic_eruption_run>"""
        ecModelRun = qDict['ecmodelrun'];
        if not ecModelRun == "best":
            ecModelRun += "Z"
        self.lastSourceTerm = sourceTerm.format(lat=latf, lon=lonf,
                                                volcano=volcano,
                                                alt=altf,
                                                outdir=self.lastOutputDir,
                                                restart="true",
                                                model_run=ecModelRun,
                                                model_start_time=modelStartDT.isoformat(),
                                                eruptions="\n".join(eruptions),
                                                runTime=runTime)
        debug("output directory: {}".format(self.lastOutputDir))
        os.makedirs(self.lastOutputDir,exist_ok=True)

        with open(os.path.join(self.lastOutputDir, "volcano.xml"),'w') as fh:
            fh.write(self.lastSourceTerm)
#         self.snap_run = _SnapRun(self)
#         self.snap_run.proc.finished.connect(self._snap_finished)
#         self.snap_run.start()
#
#         self.snap_update = _SnapUpdateThread(self)
#         self.snap_update.update_log_signal.connect(self.update_log)
#         self.snap_update.start(QThread.LowPriority)

if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    ctr = Controller()
    sys.exit(app.exec_())
