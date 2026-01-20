
task automatic load_file(
  input string filepath,
  output logic [31:0] data_out[],
  output integer length
);
  // logic [31:0] dbuf [] = new [];
  // $readmemh(filepath, dbuf);
  // length = dbuf.size();
  // data_out = dbuf;
  // `wdisplay("[info] Loaded %0d 32-bit words from %s\n", dlen, length);
endtask


task automatic store_file(
  input logic [31:0] dbuf [],
  input int len,
  input string filepath
  );
int file, i;
  begin
    // Open file for writing
    file = $fopen(filepath, "w");
    if (file == 0) begin
      `wdisplay("[error] Failed to open file %s", filepath);
      $fatal;
      return;
    end

    // Write len words from dbuf to file in hex format
    for (i = 0; i < len; i++) begin
      $fdisplay(file, "%08h", dbuf[i]);
    end

    $fclose(file);
    `wdisplay("[info] Written %0d words to file %s", len, filepath);
  end

endtask
