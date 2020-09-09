import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;
import java.util.ArrayList;
import java.util.TreeSet;
import java.util.TreeMap;

public class ProcessIndex {

   String[] suffixes = new String[] {
      "_RUN_BE.uef",
      "_RUN_E.uef",
      "_E.hq.uef",
      "_BE.uef",
      "_E.uef",
      ".uef"
   };

   public class Title {
      public int dir;
      public String filename;
      public int suffix;
      public String toString() {
         return dir + " " + filename + " " + suffix;
      }
   }

   TreeSet<String> lines = new TreeSet<String>();
   TreeSet<String> dirs = new TreeSet<String>();
   TreeMap<String, Integer> dir_id_map = new TreeMap<String, Integer>();
   List<Title> titles = new ArrayList<Title>();

   public ProcessIndex(List<String> index) {
      Integer i = 0;
      // Sort the input file
      lines.addAll(index);
      // Build a set containing the directory names
      for (String line : lines) {
         String[] parts = line.split("/");
         dirs.add(parts[1]);
      }
      // Give each unique directory a numerical index
      for (String dir : dirs) {
         dir_id_map.put(dir, i++);
      }
      // Generate the title list
      for (String line : lines) {
         String[] parts = line.split("/");
         String dir = parts[1];
         String filename = parts[2];
         int suffix = -1;
         for (i = 0; i < suffixes.length; i++) {
            if (filename.endsWith(suffixes[i])) {
               suffix = i;
               filename = filename.substring(0, filename.length() - suffixes[i].length());
            }
         }
         if (suffix < 0) {
            System.err.println("No suffix defined for " + filename);
         } else {
            Title title = new Title();
            title.dir = dir_id_map.get(dir);
            title.filename = filename;
            title.suffix = suffix;
            titles.add(title);
         }
      }
   }

   public static String toHex(int i) {
      String s = Integer.toHexString(i);
      if (s.length() == 1) {
         s = "0" + s;
      }
      return s;
   }

   public void listDirs() {
      int i;

      // Output table of directory pointers (lo byte)
      i = 0;
      System.out.println(".dirlo");
      for (String dir : dirs) {
         System.out.println("    EQUB <dir" + toHex(i++));
      }
      System.out.println();

      // Output table of directory pointers (hi byte)
      i = 0;
      System.out.println(".dirhi");
      for (String dir : dirs) {
         System.out.println("    EQUB >dir" + toHex(i++));
      }
      System.out.println();

      // Output directory strings
      i = 0;
      System.out.println(".dirstrs");
      for (String dir : dirs) {
         System.out.println(".dir" + toHex(i++));
         System.out.println("    EQUB \"" + dir + "\", &00");
      }
      System.out.println();
   }

   public void listSuffixes() {

      // Output table of suffix pointers (lo byte)
      System.out.println(".suflo");
      for (int i = 0; i < suffixes.length; i++) {
         System.out.println("    EQUB <suf" + toHex(i));
      }
      System.out.println();

      // Output table of suffix pointers (hi byte)
      System.out.println(".sufhi");
      for (int i = 0; i < suffixes.length; i++) {
         System.out.println("    EQUB >suf" + toHex(i));
      }
      System.out.println();

      // Output directory strings
      System.out.println(".sufstrs");
      for (int i = 0; i < suffixes.length; i++) {
         System.out.println(".suf" + toHex(i));
         System.out.println("    EQUB \"" + suffixes[i] + "\", &00");
      }
      System.out.println();
   }

   public void listTitles() {
      System.out.println("org &0000");
      System.out.println(".titles_start");
      int a = 0;
      for (Title title : titles) {
         // Calculate the length of a title entry
         int len = title.filename.length() + 2;
         // Don't allow a title to straddle a page boundary....
         if (a + len >= 0xFF) {
            System.out.println("    EQUB &FE");
            System.out.println("    ALIGN &100");
            System.out.println();
            a = 0;
         }
         System.out.println("    EQUB &" + toHex(title.dir) + ", \"" + title.filename + "\", &" + toHex(128 + title.suffix));
         a += len;
      }
      System.out.println(" EQUB &FF");
      System.out.println(".titles_end");
      System.out.println("SAVE \"TITLES\",titles_start, titles_end");
   }


   public static void main(String[] args) {
      try {
         ProcessIndex pi = new ProcessIndex(Files.readAllLines(Paths.get("../data/index.txt")));
         for (String arg : args) {
            if (arg.equals("-s")) {
               pi.listSuffixes();
               break;
            }
         }
         for (String arg : args) {
            if (arg.equals("-d")) {
               pi.listDirs();
               break;
            }
         }
         for (String arg : args) {
            if (arg.equals("-t")) {
               pi.listTitles();
               break;
            }
         }
      } catch (Exception e) {
         e.printStackTrace();
      }
    }
}
