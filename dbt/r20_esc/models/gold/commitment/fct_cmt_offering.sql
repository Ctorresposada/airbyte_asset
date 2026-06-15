{{
  config(
    materialized = 'table'
  )
}}

with cmt_form as (
    select * from {{ source('silver', 'stg_oracle__cmt_form') }}
),

-- Dedup: cmt_period pode ter múltiplos registros por period_id (Airbyte CDC)
cmt_period as (
    select
        period_id,
        min(period_description) as period_description
    from {{ source('silver', 'stg_oracle__cmt_period') }}
    group by period_id
),

-- Dedup: pega o menor cmt_form_item_id por formulário + período
cmt_form_item as (
    select
        cmt_form_id,
        period_id,
        min(cmt_form_item_id) as cmt_form_item_id
    from {{ source('silver', 'stg_oracle__cmt_form_item') }}
    group by cmt_form_id, period_id
),

-- Dedup: pega o título e o count_type_id do grupo por período + grupo
cmt_form_item_group as (
    select
        period_id,
        cmt_form_item_group_id,
        min(title) as title,
        min(count_type_id) as count_type_id
    from {{ source('silver', 'stg_oracle__cmt_form_item_group') }}
    group by period_id, cmt_form_item_group_id
),

cmt_count_type as (
    select
        cmt_count_type_id,
        count_type
    from {{ source('silver', 'stg_oracle__cmt_count_type') }}
),

-- Dedup: pega o primeiro full_name por contact_id
contact as (
    select
        contact_id,
        min(full_name) as full_name
    from {{ source('silver', 'stg_oracle__contact') }}
    group by contact_id
),

-- Dedup: pega o menor install_chrg por formulário + período
cmt_range_price_forms as (
    select
        cmt_form_id,
        period_id,
        min(install_chrg) as install_chrg
    from {{ source('silver', 'stg_oracle__cmt_range_price_forms') }}
    group by cmt_form_id, period_id
),

final as (
    select
        -- Identificadores
        cmt.cmt_form_id,
        cmt.commitment_id,
        cmt.cmt_order_id,
        cmt.period_id,
        cmt.cmt_group_id,
        cmt.esc_contact_id,
        cmt.esc_contact_id2,
        cmt.parent_id,
        cmt.pdetail_id,

        -- Descritivo do formulário
        cmt.cmt_form_name,
        cmt.cmt_division,
        cmt.cmt_option,
        cmt.cmt_submit_details,
        cmt.page_link,
        cmt.budgetcode,
        cmt.connect20_group,
        cmt.cbm_type,

        -- Contato ESC (desnormalizado no source)
        cmt.esc_contact_fname,
        cmt.esc_contact_mname,
        cmt.esc_contact_lname,
        cmt.esc_contact_email,

        -- Item principal
        cmt.item_decsription,           -- typo preservado do sistema de origem
        cmt.price,
        cmt.item_qty,
        cmt.item_extd_price,
        cmt.enrllsz,

        -- Itens opcionais (preços e descrições adicionais)
        cmt.item_description1,
        cmt.price1,
        cmt.item_description2,
        cmt.price2,
        cmt.item_description3,
        cmt.price3,
        cmt.item_description4,
        cmt.price4,

        -- Datas
        cmt.effective_start_date,
        cmt.effective_end_date,
        cmt.date_created,
        cmt.date_updated,

        -- Auditoria
        cmt.created_by,
        cmt.updated_by,
        cmt.commitment_manager,
        cmt.contact1,
        cmt.contact2,
        cmt.netvision_member,
        cmt.sort_order,
        cmt.apply_disc,
        cmt.onchange,
        cmt.jscript,

        -- Status
        cmt.is_active,
        case cmt.active
            when 'Y' then 'Active'
            when 'N' then 'Inactive'
            else 'Inactive'
        end                             as status,

        -- Joins
        cp.period_description,
        cfi.cmt_form_item_id,
        cfig.title                      as commitment_group,
        ct.full_name                    as esc_contact_full_name,
        crpf.install_chrg               as annual_fee,

        -- Colunas de UI (vazias — usadas no Oracle APEX)
        ''                              as edit_details,
        ''                              as edit_price,
        ''                              as edit_category,

        -- TODO: preencher quando esc_employee_data for ingerido
        cast(null as varchar)           as cmt_manager1,
        cast(null as varchar)           as cmt_manager2,
        cast(null as varchar)           as cmt_manager3,

        cct.count_type                  as count_type_used,

        -- TODO: business rule de tot_al ainda não confirmada (não há coluna óbvia em
        -- cmt_count_type nem esc_employee_data — possivelmente agregação ou cmt_enrollment)
        cast(null as double precision)  as tot_al,

        cmt.conditions,
        cmt.condition_details,
        cmt.market_price

    from cmt_form cmt
    left join cmt_period cp
        on cmt.period_id = cp.period_id
    left join cmt_form_item cfi
        on cmt.cmt_form_id = cfi.cmt_form_id
        and cmt.period_id  = cfi.period_id
    left join cmt_form_item_group cfig
        on cmt.period_id   = cfig.period_id
        and cmt.cmt_group_id = cfig.cmt_form_item_group_id
    left join contact ct
        on cmt.esc_contact_id = ct.contact_id
    left join cmt_range_price_forms crpf
        on cmt.cmt_form_id = crpf.cmt_form_id
        and cmt.period_id  = crpf.period_id
    left join cmt_count_type cct
        on cfig.count_type_id = cct.cmt_count_type_id

    where cmt.period_id = '{{ var("commitment_period_id", "19") }}'
)

select * from final
