import zipfile
import html
import os
import shutil

class DocxWriter:
    def __init__(self, filename):
        self.filename = filename
        self.paragraphs = []
        self.images = [] # list of (rId, filename, binary_data, cx, cy)

    def escape(self, text):
        return html.escape(str(text))

    def add_title(self, text, subtitle=None):
        p = f'''<w:p>
          <w:pPr>
            <w:jc w:val="center"/>
            <w:spacing w:before="360" w:after="120"/>
          </w:pPr>
          <w:r>
            <w:rPr>
              <w:b/>
              <w:color w:val="990000"/>
              <w:sz w:val="52"/>
              <w:szCs w:val="52"/>
            </w:rPr>
            <w:t>{self.escape(text)}</w:t>
          </w:r>
        </w:p>'''
        self.paragraphs.append(p)
        if subtitle:
            sub = f'''<w:p>
              <w:pPr>
                <w:jc w:val="center"/>
                <w:spacing w:before="60" w:after="300"/>
              </w:pPr>
              <w:r>
                <w:rPr>
                  <w:i/>
                  <w:color w:val="555555"/>
                  <w:sz w:val="26"/>
                  <w:szCs w:val="26"/>
                </w:rPr>
                <w:t>{self.escape(subtitle)}</w:t>
              </w:r>
            </w:p>'''
            self.paragraphs.append(sub)

    def add_heading_1(self, text):
        p = f'''<w:p>
          <w:pPr>
            <w:spacing w:before="380" w:after="120"/>
          </w:pPr>
          <w:r>
            <w:rPr>
              <w:b/>
              <w:color w:val="990000"/>
              <w:sz w:val="34"/>
              <w:szCs w:val="34"/>
            </w:rPr>
            <w:t>{self.escape(text)}</w:t>
          </w:r>
        </w:p>'''
        self.paragraphs.append(p)

    def add_heading_2(self, text):
        p = f'''<w:p>
          <w:pPr>
            <w:spacing w:before="260" w:after="100"/>
          </w:pPr>
          <w:r>
            <w:rPr>
              <w:b/>
              <w:color w:val="1E293B"/>
              <w:sz w:val="28"/>
              <w:szCs w:val="28"/>
            </w:rPr>
            <w:t>{self.escape(text)}</w:t>
          </w:r>
        </w:p>'''
        self.paragraphs.append(p)

    def add_paragraph(self, text, bold_prefix=None, italic=False):
        runs = []
        if bold_prefix:
            runs.append(f'''<w:r>
              <w:rPr>
                <w:b/>
                <w:color w:val="1E293B"/>
                <w:sz w:val="22"/>
              </w:rPr>
              <w:t xml:space="preserve">{self.escape(bold_prefix)} </w:t>
            </w:r>''')
        r_pr = ["<w:sz w:val=\"22\"/>"]
        if italic:
            r_pr.append("<w:i/>")
        runs.append(f'''<w:r>
          <w:rPr>{''.join(r_pr)}</w:rPr>
          <w:t xml:space="preserve">{self.escape(text)}</w:t>
        </w:r>''')
        p = f'''<w:p>
          <w:pPr>
            <w:spacing w:after="120" w:line="276" w:lineRule="auto"/>
          </w:pPr>
          {''.join(runs)}
        </w:p>'''
        self.paragraphs.append(p)

    def add_bullet(self, text, bold_prefix=None):
        runs = []
        runs.append('''<w:r>
          <w:rPr><w:sz w:val="22"/><w:color w:val="990000"/><w:b/></w:rPr>
          <w:t xml:space="preserve">&#9679;  </w:t>
        </w:r>''')
        if bold_prefix:
            runs.append(f'''<w:r>
              <w:rPr><w:b/><w:sz w:val="22"/><w:color w:val="1E293B"/></w:rPr>
              <w:t xml:space="preserve">{self.escape(bold_prefix)} </w:t>
            </w:r>''')
        runs.append(f'''<w:r>
          <w:rPr><w:sz w:val="22"/></w:rPr>
          <w:t xml:space="preserve">{self.escape(text)}</w:t>
        </w:r>''')
        p = f'''<w:p>
          <w:pPr>
            <w:ind w:left="400" w:hanging="200"/>
            <w:spacing w:after="80" w:line="260" w:lineRule="auto"/>
          </w:pPr>
          {''.join(runs)}
        </w:p>'''
        self.paragraphs.append(p)

    def add_callout(self, text, title="NOTE"):
        p = f'''<w:p>
          <w:pPr>
            <w:pBdr>
              <w:left w:val="single" w:sz="24" w:space="12" w:color="990000"/>
            </w:pBdr>
            <w:shd w:val="clear" w:color="auto" w:fill="F8FAFC"/>
            <w:ind w:left="240" w:right="240"/>
            <w:spacing w:before="140" w:after="140"/>
          </w:pPr>
          <w:r>
            <w:rPr><w:b/><w:sz w:val="20"/><w:color w:val="990000"/></w:rPr>
            <w:t xml:space="preserve">[{self.escape(title)}] </w:t>
          </w:r>
          <w:r>
            <w:rPr><w:sz w:val="20"/><w:color w:val="334155"/></w:rPr>
            <w:t>{self.escape(text)}</w:t>
          </w:r>
        </w:p>'''
        self.paragraphs.append(p)

    def add_image(self, image_path, caption=None, width_inches=6.0):
        if not os.path.exists(image_path):
            print(f"Warning: image {image_path} does not exist.")
            return

        with open(image_path, "rb") as f:
            data = f.read()

        idx = len(self.images) + 1
        rId = f"rIdImg{idx}"
        img_name = f"image{idx}.png"

        # Calculate EMU dimensions (1 inch = 914400 EMUs)
        # Standard page printable width is 6.0 inches
        cx = int(width_inches * 914400)
        
        # Calculate aspect ratio
        try:
            from PIL import Image
            im = Image.open(image_path)
            aspect = im.size[1] / im.size[0]
        except Exception:
            aspect = 0.42 # fallback
        cy = int(cx * aspect)

        self.images.append((rId, img_name, data, cx, cy))

        docPr_id = 1000 + idx
        img_xml = f'''<w:p>
          <w:pPr>
            <w:jc w:val="center"/>
            <w:spacing w:before="160" w:after="60"/>
          </w:pPr>
          <w:r>
            <w:drawing>
              <wp:inline distT="0" distB="0" distL="0" distR="0"
                         xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
                <wp:extent cx="{cx}" cy="{cy}"/>
                <wp:effectExtent l="0" t="0" r="0" b="0"/>
                <wp:docPr id="{docPr_id}" name="Picture {idx}"/>
                <wp:cNvGraphicFramePr>
                  <a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>
                </wp:cNvGraphicFramePr>
                <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                  <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                    <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                      <pic:nvPicPr>
                        <pic:cNvPr id="{docPr_id}" name="{img_name}"/>
                        <pic:cNvPicPr/>
                      </pic:nvPicPr>
                      <pic:blipFill>
                        <a:blip r:embed="{rId}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                        <a:stretch>
                          <a:fillRect/>
                        </a:stretch>
                      </pic:blipFill>
                      <pic:spPr>
                        <a:xfrm>
                          <a:off x="0" y="0"/>
                          <a:ext cx="{cx}" cy="{cy}"/>
                        </a:xfrm>
                        <a:prstGeom prst="rect">
                          <a:avLst/>
                        </a:prstGeom>
                      </pic:spPr>
                    </pic:pic>
                  </a:graphicData>
                </a:graphic>
              </wp:inline>
            </w:drawing>
          </w:r>
        </w:p>'''
        self.paragraphs.append(img_xml)

        if caption:
            cap_xml = f'''<w:p>
              <w:pPr>
                <w:jc w:val="center"/>
                <w:spacing w:before="40" w:after="180"/>
              </w:pPr>
              <w:r>
                <w:rPr>
                  <w:i/>
                  <w:sz w:val="18"/>
                  <w:color w:val="64748B"/>
                </w:rPr>
                <w:t>{self.escape(caption)}</w:t>
              </w:r>
            </w:p>'''
            self.paragraphs.append(cap_xml)

    def add_table(self, headers, rows):
        tbl_pr = '''<w:tblPr>
          <w:tblW w:w="9400" w:type="dxa"/>
          <w:tblBorders>
            <w:top w:val="single" w:sz="6" w:space="0" w:color="CBD5E1"/>
            <w:left w:val="none"/>
            <w:bottom w:val="single" w:sz="6" w:space="0" w:color="CBD5E1"/>
            <w:right w:val="none"/>
            <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
            <w:insideV w:val="none"/>
          </w:tblBorders>
        </w:tblPr>'''

        tbl_rows = []
        header_cells = []
        for h in headers:
            cell = f'''<w:tc>
              <w:tcPr>
                <w:shd w:val="clear" w:color="auto" w:fill="1E293B"/>
                <w:tcMar><w:top w:w="120" w:type="dxa"/><w:bottom w:w="120" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:right w:w="140" w:type="dxa"/></w:tcMar>
              </w:tcPr>
              <w:p>
                <w:pPr><w:spacing w:before="40" w:after="40"/></w:pPr>
                <w:r>
                  <w:rPr><w:b/><w:color w:val="FFFFFF"/><w:sz w:val="20"/></w:rPr>
                  <w:t>{self.escape(h)}</w:t>
                </w:r>
              </w:p>
            </w:tc>'''
            header_cells.append(cell)
        tbl_rows.append(f'<w:tr>{ "".join(header_cells) }</w:tr>')

        for idx, row in enumerate(rows):
            bg_fill = "F8FAFC" if idx % 2 == 1 else "FFFFFF"
            cells = []
            for val in row:
                cell = f'''<w:tc>
                  <w:tcPr>
                    <w:shd w:val="clear" w:color="auto" w:fill="{bg_fill}"/>
                    <w:tcMar><w:top w:w="100" w:type="dxa"/><w:bottom w:w="100" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:right w:w="140" w:type="dxa"/></w:tcMar>
                  </w:tcPr>
                  <w:p>
                    <w:pPr><w:spacing w:before="40" w:after="40"/></w:pPr>
                    <w:r>
                      <w:rPr><w:sz w:val="19"/><w:color w:val="334155"/></w:rPr>
                      <w:t>{self.escape(val)}</w:t>
                    </w:r>
                  </w:p>
                </w:tc>'''
                cells.append(cell)
            tbl_rows.append(f'<w:tr>{ "".join(cells) }</w:tr>')

        tbl = f'''<w:tbl>
          {tbl_pr}
          {''.join(tbl_rows)}
        </w:tbl>'''
        self.paragraphs.append(tbl)
        self.paragraphs.append('<w:p><w:pPr><w:spacing w:after="160"/></w:pPr></w:p>')

    def save(self):
        body_xml = "".join(self.paragraphs)
        document_xml = f'''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
    {body_xml}
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>'''

        # Document relationships including images
        doc_rels = ['''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">''']
        for rId, img_name, _, _, _ in self.images:
            doc_rels.append(f'<Relationship Id="{rId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/{img_name}"/>')
        doc_rels.append('</Relationships>')
        doc_rels_xml = "".join(doc_rels)

        # Package content types
        content_types = ['''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Default Extension="jpeg" ContentType="image/jpeg"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''']
        content_types_xml = "".join(content_types)

        # Package relationships
        root_rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>'''

        with zipfile.ZipFile(self.filename, 'w', zipfile.ZIP_DEFLATED) as z:
            z.writestr('[Content_Types].xml', content_types_xml)
            z.writestr('_rels/.rels', root_rels)
            z.writestr('word/_rels/document.xml.rels', doc_rels_xml)
            z.writestr('word/document.xml', document_xml)
            for _, img_name, data, _, _ in self.images:
                z.writestr(f'word/media/{img_name}', data)

print("Updated DocxWriter with image embedding support defined successfully.")
