import pandas as pd
# import matplotlib
import numpy as np
# matplotlib.use('Agg')
import matplotlib.pyplot as plt
import sys, os
import re 
from matplotlib.backends.backend_pdf import PdfPages


class DataCacheObject:
    """
    Cache data object
    """

    _data_cache = None  # the cache object with dict
    header = []

    def get_content(self):
        """
        main function to get real data, must be overrode by child!!!

        :return: data object
        """
        raise DataReaderError(
            "method get_dataframe must be overrode by child!")

    @property
    def data(self):
        """
        this is the entry what provides access interface to data cached

        :return: Data object
        """
        if self._data_cache is None:
            self._data_cache = self.get_content()

        return self._data_cache

    def __getitem__(self, item):
        if item not in self.header:
            return None

        return self.data[item]
class RawDataFileReader(object):
    """
    Base class to read file
    """

    filename = sys.stdin

    # build up a cache object to accelerate the file access
    _raw_data_cache = None

    def reader(self, cache_refresh=False):
        """
        main method to read raw data files.

        :param cache_refresh: mandatory refresh the cached file
        :return: list
        """
        if cache_refresh or self._raw_data_cache is None:
            if not os.path.exists(self.filename):
                raise DataReaderError(
                    "Raw data file %s is not exist" % self.filename)
            with open(self.filename, "r") as fd:
                self._raw_data_cache = fd.readlines()

        return self._raw_data_cache

    def grep(self, key_word):
        """
        Same function from Linux grep command
        :param key_word: str
        :return: list
        """
        # return self.egrep(key_word)
        return filter(lambda a: a.find(key_word) != -1, self.reader())

    def egrep(self, regex):
        """
        This method support regex strings
        :param regex: regex string
        :return: list
        """
        return filter(lambda a: re.match(regex, a), self.reader())

    def grep_iterator(self, regex):
        """
        This method is implemented to read large files.
        :param regex: regex string
        :return: iterator
        """
        regex = re.compile(regex)
        # for row in self.reader():
        with open(self.filename, "r") as fd:
            while True:
                row = fd.readline()
                if len(row) == 0:
                    break

                if regex.match(row):
                    yield row

    def read_line(self, start, end=0):
        """
        Get content from row number
        :param start: int
        :param end: int
        :return: iterator
        """
        content = self.reader()
        return content[start - 1:end - 1]

    @property
    def create_time(self):
        return os.path.getctime(self.filename)

    @property
    def file_size(self):
        return os.path.getsize(self.filename)
    
class PerfStatReader(RawDataFileReader, DataCacheObject):
    """
    perf stat out put file reader
    example:

    perf stat -e cycles,instructions  -I 100 -o event.out

    todo: need to add cgroup info into dataframe
    """
    reg = r"\s+\d+\.\d+\s+(\d|\,)+"

    def __init__(self, filename):
        self.filename = filename

    def get_content(self):
        data = []
        for row in self.grep_iterator(self.reg):
            row = row.split()
            ts = float(row[0])
            value = int(row[1].replace(",", ""))
            event = row[2]

            data.append([ts, value, event])

        df = pd.DataFrame(data, columns=["ts", "value", "event"])
        return df

    @property
    def header(self):
        return self.data["event"].unique()

    def __getitem__(self, item):
        if item not in self.header:
            raise DataReaderError(
                "Can not find event: '%s' in this file" % item)

        return self.data[self.data["event"] == item]

    
def read_raw_file(filename):
    d = PerfStatReader(filename)
    
    df = d.get_content()
    events = df.event.unique()
    
    new = {}

    for k in events:
#         k = "%s%s" %(prefix, i)
        new[k] = df[df.event == k].value.values
        
    return pd.DataFrame(new)


def process(df, prefix=""):
    df["IPC"] = df["instructions"] / df["cycles"]
    df["CPU Util(%)"] = 100 * df["instructions"] / df["tsc"]
    
    df.columns = ["%s%s"%(prefix, c) for c in df.columns]
    
    return df

def aggragate(data_files):
    agg = None
    for k, v in data_files.items():
        data = process(read_raw_file(v), k)
        
        if agg is None:
            agg = data
        else:
            agg=agg.join(data)
    return agg

class EMONRPQ(RawDataFileReader, DataCacheObject):
    reg = r"^UNC_M_RPQ_"
    
    def __init__(self, filename):
        self.filename = filename

    def get_content(self):
#         data = {"UNC_M_RPQ_CYCLES_NE.PCH0": [], 'UNC_M_RPQ_OCCUPANCY_PCH0':[]}
        data = []
        pre_ts = 0
        
        for row in self.grep_iterator(self.reg):
            row = row.replace(",", "").split()
            entry = {}
            row[1] = int(row[1])
            for i in range(2, len(row)):
                row[i] = float(row[i])
            
            #data[row[0]].append(row[1:])
            data.append(row)
            
        df = pd.DataFrame(data).rename(columns={0: "name", 1:"ts"})
#         df.reindex(index=["name", "ts"])
        return df
    
    def get_rpq_occ(self):
        data = []
        for ts in self.data.ts.unique():
            df = self.data[self.data.ts == ts]
            df.index=df.name
            del(df["name"])
            del(df["ts"])
            
            df = df.T
            tmp = list(df["UNC_M_RPQ_OCCUPANCY_PCH0"]/df["UNC_M_RPQ_CYCLES_NE.PCH0"])

            data.append(tmp)
        try:
            new_data = pd.DataFrame(data, index=range(len(data)))
            new_data = new_data.rename(columns=lambda x: "SKT%sCH%s" % ((x-2)//8, (x-2)%8))

            return new_data
        except:
            print(self.filename)
            return  df

def plot(df, emon=None, filename=None,  metrics=["IPC", "CPU Util(%)"]):
    with PdfPages(filename) as pdf:
        fig, axs = plt.subplots(len(metrics), 1)
        idx = 0
        for metric in metrics:
            tmp = []
            for k in df.columns:
                if k.endswith(metric):
                    tmp.append(k)

            selected = df[tmp]
            selected.plot(ax=axs[idx], linewidth=0.75)
            axs[idx].set_title(metric)

            axs[idx].autoscale_view(True)

            idx +=1    
        fig.tight_layout()
        pdf.savefig()
#         fig.close()
        
        if emon is None:
            emon="emon.dat"
#        try:
        fig, axs = plt.subplots()
        
        emon = EMONRPQ(emon)
        emon.get_content()

        df = emon.get_rpq_occ()
        df.plot(ax=axs)
        axs.set_title("RPQ occ")
#        except Exception as e:
#            print(e)

        fig.tight_layout()
        pdf.savefig()
    
#     if filename is None:
#         plt.show()
#     else:
#         if filename.endswith("pdf"):
#             with PdfPages(filename) as pdf:
#                 pdf.savefig()
#         else:
#             plt.savefig(filename, dpi=300, transparent=True, pad_inches=0)
#     plt.close()
    
def main(main_path):
    for folder in os.listdir(main_path):
        
        if folder.endswith(".sh"):
            continue

        files = {
            "hp": os.path.join(main_path, folder, "perf_hp.csv"),
            "lp": os.path.join(main_path, folder, "perf_lp.csv"),
        }
        emon = os.path.join(main_path, folder, "emon.dat")
        p = aggragate(files)
        f = os.path.join(main_path, folder, "summary.pdf")
        
        plot(p, emon, f)
        
if __name__ == "__main__":
    main_path = sys.argv[1]
    main(main_path)
