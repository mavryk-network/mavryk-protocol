// For the script inspiration see: https://doc.kaitai.io/lang_javascript.html

// TODO: Document the script.

var arguments = process.argv

const parser_path = arguments[2]
const input_path = arguments[3]

const fs = require("fs");
const OctezData = require(parser_path);
const KaitaiStream = require('kaitai-struct/KaitaiStream');

const fileContent = fs.readFileSync(input_path);
const parsedEncoding = new OctezData(new KaitaiStream(fileContent));
console.log(parsedEncoding);